SWIFTLINT_ARGS = --strict --quiet
OXFMT_ARGS = "WebRemoteControlFrontend"
OXLINT_ARGS = "WebRemoteControlFrontend"
PYTHON_DIRS = \
	tests \
	utils
PERIPHERY_ARGS = \
	--index-exclude "Moblin/Integrations/Tesla/Protobuf/*" \
	--disable-update-check
CODESPELL_ARGS = \
	--skip "*.xcstrings,libsrt.xcframework,VoicesView.swift,TextAlignerSuite.swift,Web,node_modules,package-lock.json,*.log" \
	--ignore-words-list "inout,froms,soop,medias,deactive,upto,datas,ro,lightyears"
ISORT_ARGS = \
	--force-single-line-imports \
	$(PYTHON_DIRS)

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
	isort $(ISORT_ARGS)
	ruff format $(PYTHON_DIRS)

style-check:
	swiftformat $(CODE_DIRS) --lint
	oxfmt $(OXFMT_ARGS) --check
	isort $(ISORT_ARGS) --check
	ruff format $(PYTHON_DIRS) --check

lint:
	swiftlint lint $(SWIFTLINT_ARGS) $(CODE_DIRS)
	oxlint $(OXLINT_ARGS)
	pylint $(PYTHON_DIRS)
	ruff check $(PYTHON_DIRS)
	mypy $(PYTHON_DIRS)
	python utils/xcstringslint.py Common/Localizable.xcstrings

lint-fix:
	python utils/xcstringslint.py --fix Common/Localizable.xcstrings

periphery:
	periphery scan $(PERIPHERY_ARGS)

spell-check:
	codespell $(CODESPELL_ARGS) $(CODE_DIRS) $(PYTHON_DIRS)

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
