SWIFT_DIRS += "Common"
SWIFT_DIRS += "Moblin"
SWIFT_DIRS += "Moblin Watch"
SWIFT_DIRS += "Moblin Widget"
SWIFT_DIRS += "Moblin Live Activity"
SWIFT_DIRS += "Moblin Screen Recording"
SWIFT_DIRS += "MoblinTests"

WEB_DIRS += WebRemoteControlFrontend
WEB_DIRS += tests/utils

PYTHON_DIRS += tests
PYTHON_DIRS += utils

CODE_DIRS += $(SWIFT_DIRS)
CODE_DIRS += $(WEB_DIRS)
CODE_DIRS += $(PYTHON_DIRS)

TEST_MAKE_ARGS = -C tests TEST_ARGS="$(TEST_ARGS)"

SHELL = /usr/bin/env bash

default:

style:
	swiftformat $(SWIFT_DIRS)
	oxfmt $(WEB_DIRS)
	isort $(PYTHON_DIRS)
	ruff format $(PYTHON_DIRS)

style-check:
	swiftformat $(SWIFT_DIRS) --lint
	oxfmt $(WEB_DIRS) --check
	isort $(PYTHON_DIRS) --check
	ruff format $(PYTHON_DIRS) --check

lint:
	swiftlint lint --quiet $(SWIFT_DIRS)
	oxlint $(WEB_DIRS)
	pylint $(PYTHON_DIRS)
	ruff check $(PYTHON_DIRS)
	mypy $(PYTHON_DIRS)
	python utils/xcstringslint.py Common/Localizable.xcstrings

lint-fix:
	python utils/xcstringslint.py --fix Common/Localizable.xcstrings

periphery:
	periphery scan

spell-check:
	codespell $(CODE_DIRS)

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

publish:
	python utils/publish.py $(PUBLISH_ARGS)

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
