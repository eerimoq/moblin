import sys
import json
import re
import argparse
import itertools
from pathlib import Path

# Matches iOS/Swift format specifiers with an optional positional prefix.
# Handles: %@, %lld, %llu, %d, %f, %u and positional forms like %1$@, %2$lld.
SPECIFIER_RE = re.compile(r'%(\d+\$)?(@|lld|llu|[dfu])')


def extract_specifiers(s):
    return [(m.group(1), m.group(2)) for m in SPECIFIER_RE.finditer(s)]


def check_format_specifiers(string_in_code, localized_string, language_code):
    errors = []
    code_specs = extract_specifiers(string_in_code)
    loc_specs = extract_specifiers(localized_string)

    code_types = sorted(t for _, t in code_specs)
    loc_types = sorted(t for _, t in loc_specs)

    if code_types != loc_types:
        errors.append(
            f'  [{language_code}] Format specifier mismatch: '
            f'code={[t for _, t in code_specs]}, '
            f'localized={[t for _, t in loc_specs]}'
        )
    elif len(code_specs) > 1:
        if any(pos is None for pos, _ in loc_specs):
            errors.append(
                f'  [{language_code}] Missing positional prefixes in: '
                f'{repr(localized_string)}'
            )

    return errors


def fix_localized_string(string_in_code, localized_string):
    code_specs = extract_specifiers(string_in_code)
    loc_specs = extract_specifiers(localized_string)

    code_types = sorted(t for _, t in code_specs)
    loc_types = sorted(t for _, t in loc_specs)

    if code_types != loc_types or len(code_specs) != len(loc_specs):
        return None

    if len(code_specs) <= 1:
        return localized_string

    if all(pos is not None for pos, _ in loc_specs):
        return localized_string

    idx = itertools.count(1)

    def replacer(m):
        return f'%{next(idx)}${m.group(2)}'

    return SPECIFIER_RE.sub(replacer, localized_string)


def main():
    parser = argparse.ArgumentParser(
        description='Lint format specifiers in xcstrings localization files.'
    )
    parser.add_argument('xcstrings_path', help='Path to the .xcstrings file')
    parser.add_argument('--fix',
                        action='store_true',
                        help='Fix found problems and write the result back to the file')
    args = parser.parse_args()

    xcstrings_path = Path(args.xcstrings_path)
    localizable = json.loads(xcstrings_path.read_text())

    errors_found = False
    modified = False

    for string_in_code, value in localizable['strings'].items():
        localizations = value.get('localizations')
        if not localizations:
            continue

        string_errors = []

        for language_code, lval in localizations.items():
            string_unit = lval.get('stringUnit')
            if not string_unit:
                continue

            localized_string = string_unit.get('value', '')
            errors = check_format_specifiers(string_in_code, localized_string,
                                             language_code)

            if errors:
                string_errors.extend(errors)

                if args.fix:
                    fixed = fix_localized_string(string_in_code, localized_string)
                    if fixed is not None and fixed != localized_string:
                        string_unit['value'] = fixed
                        modified = True

        if string_errors:
            errors_found = True
            print(f'Error in {repr(string_in_code)}:')
            for error in string_errors:
                print(error)

    if args.fix and modified:
        xcstrings_path.write_text(
            json.dumps(localizable, indent=2, ensure_ascii=False,
                       separators=(',', ' : '))
        )

    if errors_found and not args.fix:
        sys.exit(1)


main()
