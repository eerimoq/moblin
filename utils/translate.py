import sys
import json
from googletrans import Translator
from pathlib import Path


LANGUAGES = [
    ("sv", "sv"),
    ("es", "es"),
    ("de", "de"),
    ("fr", "fr"),
    ("pl", "pl"),
    ("vi", "vi"),
    ("nl", "nl"),
    # ("zh-HK", "zh-HK"),
    ("zh-Hans", "zh-cn"),
    ("zh-Hant", "zh-tw"),
    ("el", "el"),
    ("tr", "tr"),
    #("pt-BR", "pt"),
    #("pt-PT", "pt"),
    ("id", "id"),
    ("ja", "ja"),
    ("hi", "hi"),
    ("ko", "ko")
]


def needs_translation(item):
    state = item['stringUnit']['state']

    return state not in ['translated', 'needs_review']


def main():
    localizable_xcstrings_path = Path(sys.argv[1])
    localizable = json.loads(localizable_xcstrings_path.read_text())
    translator = Translator()

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
                    translated = translator.translate(
                        english,
                        src='en',
                        dest=google_language).text
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
