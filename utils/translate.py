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
    ("zh-Hant", "zh-TW"),
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
    ("uk", "uk")
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

            for xcode_language, google_language in LANGUAGES:
                item = localizations.get(xcode_language)

                if item is None or needs_translation(item):
                    if not english.strip():
                        continue

                    print(f'Translating "{english}" to {xcode_language}')
                    translator = GoogleTranslator(source='en', target=google_language)
                    translated = translator.translate(english)
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
