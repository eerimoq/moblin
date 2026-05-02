import sys
import json
from pathlib import Path


def check_format_specifiers(string_in_code, localized_string, language_code):
    pass


def main():
    localizable_xcstrings_path = Path(sys.argv[1])
    localizable = json.loads(localizable_xcstrings_path.read_text())

    for string_in_code, value in localizable['strings'].items():
        localizations = value.get('localizations')

        for language_code, value in localizations.items():
            check_format_specifiers(string_in_code,
                                    value['stringUnit']['value'],
                                    language_code)


main()
