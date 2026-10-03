import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from pyleetspeak2.LeetSpeaker import LeetSpeaker
from xcstrings import Localization
from xcstrings import Localizations
from xcstrings import load
from xcstrings import store


@dataclass
class Language:
    xcode_languages: list[str]
    name: str


LANGUAGES = [
    Language(["sv"], "Swedish"),
    Language(["es"], "Spanish"),
    Language(["de"], "German"),
    Language(["fi"], "Finnish"),
    Language(["fr"], "French"),
    Language(["pl"], "Polish"),
    Language(["vi"], "Vietnamese"),
    Language(["nl"], "Dutch"),
    Language(["zh-Hans"], "Simplified Chinese"),
    Language(["zh-Hant", "zh-Hant-TW"], "Traditional Chinese (Taiwan)"),
    Language(["tr"], "Turkish"),
    Language(["pt-BR"], "Brazilian Portuguese"),
    Language(["pt-PT"], "European Portuguese"),
    Language(["id"], "Indonesian"),
    Language(["it"], "Italian"),
    Language(["ja"], "Japanese"),
    Language(["hi"], "Hindi"),
    Language(["ko"], "Korean"),
    Language(["ru"], "Russian"),
    Language(["uk"], "Ukrainian"),
    Language(["sk"], "Slovak"),
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


@dataclass
class String:
    english: str
    comment: str
    localizations: Localizations
    missing: list[Language]


@dataclass
class Batch:
    strings: list[String]

    def language_names(self) -> list[str]:
        names: set[str] = set()
        for string in self.strings:
            for language in string.missing:
                names.add(language.name)
        return sorted(names)

    def apply(self, translations: dict[int, dict[str, Any]]) -> None:
        for index, string in enumerate(self.strings):
            entry = translations.get(index)
            if entry is None:
                print(f'Missing translation of "{string.english}"')
                continue
            for language in string.missing:
                translated = entry.get(language.name)
                if translated is None:
                    continue
                for xcode_language in language.xcode_languages:
                    item = string.localizations.get(xcode_language)
                    if item is None or needs_translation(item):
                        string.localizations[xcode_language] = {
                            "stringUnit": {"state": "needs_review", "value": translated}
                        }


def to_leetspeak(leet_speaker: LeetSpeaker, text: str) -> str:
    parts: list[str] = []
    position = 0
    for match in PRESERVED_RE.finditer(text):
        parts.append(leet_speaker.text2leet(text[position : match.start()]))
        parts.append(match.group(0))
        position = match.end()
    parts.append(leet_speaker.text2leet(text[position:]))
    return "".join(parts)


def needs_translation(item: Localization) -> bool:
    state = item["stringUnit"]["state"]
    return state not in ["translated", "needs_review"]


def missing_languages(localizations: Localizations) -> list[Language]:
    missing: list[Language] = []
    for language in LANGUAGES:
        for xcode_language in language.xcode_languages:
            item = localizations.get(xcode_language)
            if item is None or needs_translation(item):
                missing.append(language)
                break
    return missing


def translate_batch(batch: Batch) -> dict[int, dict[str, Any]]:
    language_names = batch.language_names()
    schema = {
        "type": "object",
        "properties": {
            "translations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "integer"},
                        **{name: {"type": "string"} for name in language_names},
                    },
                    "required": ["id", *language_names],
                },
            }
        },
        "required": ["translations"],
    }
    strings = [
        {"id": index, "english": string.english, "comment": string.comment}
        for index, string in enumerate(batch.strings)
    ]
    prompt = (
        f"Translate each English string below to {', '.join(language_names)}. "
        "Return one entry per id.\n\n" + json.dumps(strings, indent=2, ensure_ascii=False)
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


def main() -> None:
    localizable_xcstrings_path = Path(sys.argv[1])
    localizable = load(localizable_xcstrings_path)
    leet_speaker = LeetSpeaker(mode="basic", change_prb=1, change_frq=1, uniform_change=True)
    pending: list[String] = []
    for english, value in localizable["strings"].items():
        localizations = value.setdefault("localizations", {})
        if not english.strip():
            continue
        missing = missing_languages(localizations)
        if missing:
            pending.append(String(english, value.get("comment", ""), localizations, missing))
        item = localizations.get(LEETSPEAK_LANGUAGE)
        if item is None or needs_translation(item):
            localizations[LEETSPEAK_LANGUAGE] = {
                "stringUnit": {
                    "state": "translated",
                    "value": to_leetspeak(leet_speaker, english),
                }
            }
    store(localizable_xcstrings_path, localizable)
    batches = [Batch(pending[i : i + BATCH_SIZE]) for i in range(0, len(pending), BATCH_SIZE)]
    print(f"Translating {len(pending)} strings in {len(batches)} batches")
    with ThreadPoolExecutor(max_workers=WORKERS) as executor:
        futures = {executor.submit(translate_batch, batch): batch for batch in batches}
        for number, future in enumerate(as_completed(futures), 1):
            batch = futures[future]
            try:
                batch.apply(future.result())
            except Exception as error:
                print(f'Batch starting with "{batch.strings[0].english}" failed: {error}')
                continue
            store(localizable_xcstrings_path, localizable)
            print(f"Batch {number}/{len(batches)} done")


main()
