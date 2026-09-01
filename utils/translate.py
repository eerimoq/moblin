import json
import re
import sys
from pathlib import Path

from deep_translator import GoogleTranslator
from pyleetspeak2.LeetSpeaker import LeetSpeaker

LANGUAGES = [
    ("sv", "sv"),
    ("es", "es"),
    ("de", "de"),
    ("fi", "fi"),
    ("fr", "fr"),
    ("pl", "pl"),
    ("vi", "vi"),
    ("nl", "nl"),
    # ("zh-HK", "zh-HK"),
    ("zh-Hans", "zh-CN"),
    (["zh-Hant", "zh-Hant-TW"], "zh-TW"),
    ("tr", "tr"),
    ("pt-BR", "pt"),
    ("pt-PT", "pt"),
    ("id", "id"),
    ("it", "it"),
    ("ja", "ja"),
    ("hi", "hi"),
    ("ko", "ko"),
    ("ru", "ru"),
    ("uk", "uk"),
    ("sk", "sk"),
]

LEETSPEAK_LANGUAGE = "eo"

PRESERVED_RE = re.compile(r"%(?:\d+\$)?(?:@|lld|llu|[dfu])|[^\x00-\x7f]+")


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


def main():
    localizable_xcstrings_path = Path(sys.argv[1])
    localizable = json.loads(localizable_xcstrings_path.read_text(encoding="utf-8"))
    leet_speaker = LeetSpeaker(mode="basic", change_prb=1, change_frq=1, uniform_change=True)

    try:
        for english, value in localizable["strings"].items():
            localizations = value.get("localizations")

            if localizations is None:
                localizations = {}
                value["localizations"] = localizations

            for xcode_languages, google_language in LANGUAGES:
                translated = None

                if isinstance(xcode_languages, str):
                    xcode_languages = [xcode_languages]

                for xcode_language in xcode_languages:
                    item = localizations.get(xcode_language)

                    if item is None or needs_translation(item):
                        if not english.strip():
                            continue

                        if translated is None:
                            print(f'Translating "{english}" to {", ".join(xcode_languages)}')
                            translator = GoogleTranslator(source="en", target=google_language)

                            try:
                                translated = translator.translate(english)
                            except Exception:
                                translated = english

                        localizations[xcode_language] = {
                            "stringUnit": {"state": "needs_review", "value": translated}
                        }

            item = localizations.get(LEETSPEAK_LANGUAGE)

            if (item is None or needs_translation(item)) and english.strip():
                print(f'Translating "{english}" to {LEETSPEAK_LANGUAGE}')
                localizations[LEETSPEAK_LANGUAGE] = {
                    "stringUnit": {
                        "state": "needs_review",
                        "value": to_leetspeak(leet_speaker, english),
                    }
                }
    finally:
        localizable_xcstrings_path.write_text(
            json.dumps(localizable, indent=2, ensure_ascii=False, separators=(",", " : ")),
            encoding="utf-8",
        )


main()
