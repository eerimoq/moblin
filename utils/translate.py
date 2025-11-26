import sys
import json
from pathlib import Path
from deep_translator import GoogleTranslator

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
    ("el", "el"),
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
    ("sk", "sk")
]


def needs_translation(item):
    state = item['stringUnit']['state']

    return state not in ['translated', 'needs_review']


def main():
    localizable_xcstrings_path = Path(sys.argv[1])
    localizable = json.loads(localizable_xcstrings_path.read_text())

    try:
        for english, value in localizable['strings'].items():
            localizations = value.get('localizations')

            if localizations is None:
                localizations = {}
                value['localizations'] = localizations
                
            for xcode_languages, google_language in LANGUAGES:
                translated = None

                if not isinstance(xcode_languages, list):
                    xcode_languages = [xcode_languages]

                for xcode_language in xcode_languages:
                    item = localizations.get(xcode_language)

                    if item is None or needs_translation(item):
                        if not english.strip():
                            continue

                        if translated is None:
                            print(f'Translating "{english}" to {", ".join(xcode_languages)}')
                            translator = GoogleTranslator(source='en', target=google_language)

                            try:
                                translated = translator.translate(english)
                            except Exception:
                                translated = english

                        localizations[xcode_language] = {
                            'stringUnit': {
                                'state': 'needs_review',
                                'value': translated
                            }
                        }
    finally:
        localizable_xcstrings_path.write_text(
            json.dumps(localizable,
                       indent=2,
                       separators=(',', ' : ')))


main()
