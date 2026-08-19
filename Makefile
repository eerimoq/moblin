OXFMT_ARGS = "WebRemoteControlFrontend"
OXLINT_ARGS = "WebRemoteControlFrontend"
PYTHON_DIRS = \
	tests \
	utils

CODE_DIRS += "Common"
CODE_DIRS += "Moblin"
CODE_DIRS += "Moblin Watch"
CODE_DIRS += "Moblin Widget"
CODE_DIRS += "Moblin Live Activity"
CODE_DIRS += "Moblin Screen Recording"
CODE_DIRS += "MoblinTests"
CODE_DIRS += "WebRemoteControlFrontend"

TEST_MAKE_ARGS = -C tests TEST_ARGS="$(TEST_ARGS)"

SHELL = /usr/bin/env bash

default:

style:
	swiftformat $(CODE_DIRS)
	oxfmt $(OXFMT_ARGS)
	isort $(PYTHON_DIRS)
	ruff format $(PYTHON_DIRS)

style-check:
	swiftformat $(CODE_DIRS) --lint
	oxfmt $(OXFMT_ARGS) --check
	isort $(PYTHON_DIRS) --check
	ruff format $(PYTHON_DIRS) --check

lint:
	swiftlint lint --quiet $(CODE_DIRS)
	oxlint $(OXLINT_ARGS)
	pylint $(PYTHON_DIRS)
	ruff check $(PYTHON_DIRS)
	mypy $(PYTHON_DIRS)
	python utils/xcstringslint.py Common/Localizable.xcstrings

lint-fix:
	python utils/xcstringslint.py --fix Common/Localizable.xcstrings

periphery:
	periphery scan

spell-check:
	codespell $(CODE_DIRS) $(PYTHON_DIRS)

test:
	python -m tests.test $(TEST_ARGS)

test-stability:
	python -m tests.stability $(TEST_ARGS)

test-stability-watch:
	python -m tests.watch

test-generate-device-settings-clipboard:
	python -m tests.generate_device_settings $(TEST_ARGS)

test-generate-device-settings-stdout:
	python -m tests.generate_device_settings --force-stdout $(TEST_ARGS)

machine-translate:
	python utils/translate.py Common/Localizable.xcstrings

pack-exported-localizations:
	cd Moblin\ Localizations && \
	for f in * ; do \
	    python ../utils/xliff.py $$f/Localized\ Contents/*.xliff && \
	    zip -qr $$f.zip $$f && \
	    rm -rf $$f ; \
	done

web-remote-control-frontend-prepare:
	cd WebRemoteControlFrontend && \
	npm install --loglevel warn

web-remote-control-frontend-build:
	cd WebRemoteControlFrontend && \
	NODE_NO_WARNINGS=1 npx tsc --noEmit && \
	NODE_NO_WARNINGS=1 npm run build --silent

npm-latest-args = \
	python -c "import json; print(' '.join(f'{d}@latest' for d in json.load(open('package.json'))['$(1)']))"

web-remote-control-frontend-update-dependencies:
	cd WebRemoteControlFrontend && \
	npm install $$($(call npm-latest-args,dependencies)) && \
	npm install --save-dev $$($(call npm-latest-args,devDependencies))
