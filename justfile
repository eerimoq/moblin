set shell := ["bash", "-cu"]

swift_dirs := '"Common" "Moblin" "Moblin Watch" "Moblin Widget" "Moblin Live Activity" "Moblin Mac" "Moblin Screen Recording" "MoblinTests"'

web_dirs := 'WebRemoteControlFrontend tests/utils'

python_dirs := 'tests utils'

config_dir := '.config'

code_dirs := swift_dirs + ' ' + web_dirs + ' ' + python_dirs

npm_latest_args := '''python -c "import json, sys; print(' '.join(f'{d}@latest' for d in json.load(open('package.json'))[sys.argv[1]]))"'''

default:
    @just --list

style:
    swiftformat --config {{config_dir}}/swiftformat {{swift_dirs}}
    oxfmt --config {{config_dir}}/oxfmtrc.json --ignore-path .gitignore --ignore-path {{config_dir}}/prettierignore {{web_dirs}}
    isort --settings-path {{config_dir}}/isort.cfg {{python_dirs}}
    ruff format --config {{config_dir}}/ruff.toml {{python_dirs}}

style-check:
    swiftformat --config {{config_dir}}/swiftformat {{swift_dirs}} --lint
    oxfmt --config {{config_dir}}/oxfmtrc.json --ignore-path .gitignore --ignore-path {{config_dir}}/prettierignore {{web_dirs}} --check
    isort --settings-path {{config_dir}}/isort.cfg {{python_dirs}} --check
    ruff format --config {{config_dir}}/ruff.toml {{python_dirs}} --check

lint:
    swiftlint lint --quiet --config {{config_dir}}/swiftlint.yml {{swift_dirs}}
    oxlint {{web_dirs}}
    pylint --rcfile {{config_dir}}/pylintrc {{python_dirs}}
    ruff check --config {{config_dir}}/ruff.toml {{python_dirs}}
    mypy --config-file {{config_dir}}/mypy.ini {{python_dirs}}
    python utils/xcstringslint.py Common/Localizable.xcstrings

lint-fix:
    python utils/xcstringslint.py --fix Common/Localizable.xcstrings

periphery:
    periphery scan --config {{config_dir}}/periphery.yml

spell-check:
    codespell --config {{config_dir}}/codespellrc {{code_dirs}}

test *args:
    python -m tests.test {{args}}

test-stability *args:
    python -m tests.stability {{args}}

test-stability-watch:
    python -m tests.watch

test-generate-device-settings-clipboard *args:
    python -m tests.generate_device_settings {{args}}

test-generate-device-settings-stdout *args:
    python -m tests.generate_device_settings --force-stdout {{args}}

publish *args:
    python utils/publish.py {{args}}

machine-translate:
    python utils/translate.py Common/Localizable.xcstrings

pack-exported-localizations:
    #!/usr/bin/env bash
    set -eu
    cd "Moblin Localizations"
    for f in * ; do
        python ../utils/xliff.py "$f/Localized Contents/"*.xliff
        zip -qr "$f.zip" "$f"
        rm -rf "$f"
    done

web-remote-control-frontend-prepare:
    cd WebRemoteControlFrontend && \
    npm install --loglevel warn

web-remote-control-frontend-build:
    cd WebRemoteControlFrontend && \
    NODE_NO_WARNINGS=1 npx tsc --noEmit && \
    NODE_NO_WARNINGS=1 npm run build --silent

web-remote-control-frontend-update-dependencies:
    cd WebRemoteControlFrontend && \
    npm install $({{npm_latest_args}} dependencies) && \
    npm install --save-dev $({{npm_latest_args}} devDependencies)
