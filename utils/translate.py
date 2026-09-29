import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import as_completed
from pathlib import Path

from pyleetspeak2.LeetSpeaker import LeetSpeaker

LANGUAGES = [
    (["sv"], "Swedish"),
    (["es"], "Spanish"),
    (["de"], "German"),
    (["fi"], "Finnish"),
    (["fr"], "French"),
    (["pl"], "Polish"),
    (["vi"], "Vietnamese"),
    (["nl"], "Dutch"),
    (["zh-Hans"], "Simplified Chinese"),
    (["zh-Hant", "zh-Hant-TW"], "Traditional Chinese (Taiwan)"),
    (["tr"], "Turkish"),
    (["pt-BR"], "Brazilian Portuguese"),
    (["pt-PT"], "European Portuguese"),
    (["id"], "Indonesian"),
    (["it"], "Italian"),
    (["ja"], "Japanese"),
    (["hi"], "Hindi"),
    (["ko"], "Korean"),
    (["ru"], "Russian"),
    (["uk"], "Ukrainian"),
    (["sk"], "Slovak"),
]

LEETSPEAK_LANGUAGE = "eo"
PRESERVED_RE = re.compile(r"%(?:\d+\$)?(?:@|lld|llu|[dfu])|[^\x00-\x7f]+")
BATCH_SIZE = 25
WORKERS = 4

SYSTEM_PROMPT = """\
You translate user interface strings for Moblin, an iOS app for IRL live streaming to Twitch, \
YouTube, Kick and others over RTMP, SRT(LA), RIST and WebRTC. Use the terminology a streamer \
would expect in each language, keep translations about as short as the English original, and \
match its capitalization style. Keep technical terms and product names (bitrate, SRT, RTMP, \
OBS, Twitch, ...) untranslated when that is what native speakers use. Format specifiers such as \
%@, %lld, %d, %f and positional forms like %1$@ must appear in every translation exactly as in \
the English string, with the same count; reorder positional ones if grammar requires it. \
Preserve newlines and leading/trailing whitespace. Each string may have a comment from the \
developer describing its context; use it to pick the right meaning but never translate it."""


def to_leetspeak(leet_speaker, text):
    parts = []
    position = 0
    for match in PRESERVED_RE.finditer(text):
        parts.append(leet_speaker.text2leet(text[position : match.start()]))
        parts.append(match.group(0))
        position = match.end()
    parts.append(leet_speaker.text2leet(text[position:]))
    return "".join(parts)


def needs_translation(item):
    state = item["stringUnit"]["state"]
    return state not in ["translated", "needs_review"]


def missing_languages(localizations):
    missing = []
    for xcode_languages, language in LANGUAGES:
        for xcode_language in xcode_languages:
            item = localizations.get(xcode_language)
            if item is None or needs_translation(item):
                missing.append((xcode_languages, language))
                break
    return missing


def translate_batch(batch):
    languages = sorted({language for _, _, missing in batch for _, language in missing})
    schema = {
        "type": "object",
        "properties": {
            "translations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        **{language: {"type": "string"} for language in languages},
                    },
                    "required": ["id", *languages],
                },
            }
        },
        "required": ["translations"],
    }
    strings = [
        {"id": index, "english": english, "comment": comment}
        for index, (english, comment, _) in enumerate(batch)
    ]
    prompt = (
        f"Translate each English string below to {', '.join(languages)}. Return one entry per id.\n\n"
        + json.dumps(strings, indent=2, ensure_ascii=False)
    )
    result = subprocess.run(
        [
            "claude",
            "-p",
            "--model",
            "sonnet",
            "--output-format",
            "json",
            "--tools",
            "",
            "--no-session-persistence",
            "--strict-mcp-config",
            "--setting-sources",
            "",
            "--system-prompt",
            SYSTEM_PROMPT,
            "--json-schema",
            json.dumps(schema),
            prompt,
        ],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        check=True,
    )
    output = json.loads(result.stdout)
    if output.get("is_error"):
        raise RuntimeError(output.get("result"))
    return {entry["id"]: entry for entry in output["structured_output"]["translations"]}


def apply_translations(localizable, batch, translations):
    for index, (english, _, missing) in enumerate(batch):
        entry = translations.get(index)
        if entry is None:
            print(f'Missing translation of "{english}"')
            continue
        localizations = localizable["strings"][english]["localizations"]
        for xcode_languages, language in missing:
            translated = entry.get(language)
            if translated is None:
                continue
            for xcode_language in xcode_languages:
                item = localizations.get(xcode_language)
                if item is None or needs_translation(item):
                    localizations[xcode_language] = {
                        "stringUnit": {"state": "needs_review", "value": translated}
                    }


def store(localizable_xcstrings_path, localizable):
    localizable_xcstrings_path.write_text(
        json.dumps(localizable, indent=2, ensure_ascii=False, separators=(",", " : ")),
        encoding="utf-8",
    )


def main():
    localizable_xcstrings_path = Path(sys.argv[1])
    localizable = json.loads(localizable_xcstrings_path.read_text(encoding="utf-8"))
    leet_speaker = LeetSpeaker(mode="basic", change_prb=1, change_frq=1, uniform_change=True)
    pending = []
    for english, value in localizable["strings"].items():
        localizations = value.setdefault("localizations", {})
        if not english.strip():
            continue
        missing = missing_languages(localizations)
        if missing:
            pending.append((english, value.get("comment", ""), missing))
        item = localizations.get(LEETSPEAK_LANGUAGE)
        if item is None or needs_translation(item):
            localizations[LEETSPEAK_LANGUAGE] = {
                "stringUnit": {
                    "state": "needs_review",
                    "value": to_leetspeak(leet_speaker, english),
                }
            }
    store(localizable_xcstrings_path, localizable)
    batches = [pending[i : i + BATCH_SIZE] for i in range(0, len(pending), BATCH_SIZE)]
    print(f"Translating {len(pending)} strings in {len(batches)} batches")
    with ThreadPoolExecutor(max_workers=WORKERS) as executor:
        futures = {executor.submit(translate_batch, batch): batch for batch in batches}
        for number, future in enumerate(as_completed(futures), 1):
            batch = futures[future]
            try:
                apply_translations(localizable, batch, future.result())
            except Exception as error:
                print(f'Batch starting with "{batch[0][0]}" failed: {error}')
                continue
            store(localizable_xcstrings_path, localizable)
            print(f"Batch {number}/{len(batches)} done")


main()
