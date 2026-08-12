SWIFTFORMAT_ARGS = \
	--maxwidth 110 \
	--swiftversion 5.9 \
	--exclude Moblin/Integrations/Tesla/Protobuf \
	--disable docComments \
	--ifdef no-indent
SWIFTLINT_ARGS = --strict --quiet
OXFMT_ARGS = "WebRemoteControlFrontend"
OXLINT_ARGS = "WebRemoteControlFrontend"
PYTHON_DIRS = \
	tests \
	utils
RUFF_FORMAT_ARGS = \
	--line-length 110 \
	$(PYTHON_DIRS)
PERIPHERY_ARGS = \
	--index-exclude "Moblin/Integrations/Tesla/Protobuf/*" \
	--disable-update-check
CODESPELL_ARGS = \
	--skip "*.xcstrings,libsrt.xcframework,VoicesView.swift,TextAlignerSuite.swift,Web,node_modules,package-lock.json,*.log" \
	--ignore-words-list "inout,froms,soop,medias,deactive,upto,datas,ro,lightyears"
PYLINT_ARGS = \
	--disable missing-module-docstring \
	--disable missing-class-docstring \
	--disable missing-function-docstring \
	--disable too-many-nested-blocks \
	--disable too-many-locals \
	--disable too-many-arguments \
	--disable too-many-positional-arguments \
	--disable too-many-instance-attributes \
	--disable too-few-public-methods \
	--disable too-many-public-methods \
	--disable broad-exception-caught \
	--disable broad-exception-raised \
	--disable duplicate-code \
	--disable line-too-long \
	--disable consider-using-with \
	--disable no-else-return \
	--recursive yes \
	$(PYTHON_DIRS)
ISORT_ARGS = \
	--force-single-line-imports \
	$(PYTHON_DIRS)
MYPY_ARGS = \
	--check-untyped-defs \
	--ignore-missing-imports \
	--warn-redundant-casts \
	--warn-unused-ignores \
	--warn-no-return \
	--strict-equality \
	--no-error-summary \
	$(PYTHON_DIRS)
RUFF_CHECK_ARGS = \
	--isolated \
	--select E9,F \
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
	swiftformat $(CODE_DIRS) $(SWIFTFORMAT_ARGS)
	oxfmt $(OXFMT_ARGS)
	isort $(ISORT_ARGS)
	ruff format $(RUFF_FORMAT_ARGS)

style-check:
	swiftformat $(CODE_DIRS) $(SWIFTFORMAT_ARGS) --lint
	oxfmt $(OXFMT_ARGS) --check
	isort $(ISORT_ARGS) --check
	ruff format $(RUFF_FORMAT_ARGS) --check

lint:
	swiftlint lint $(SWIFTLINT_ARGS) $(CODE_DIRS)
	oxlint $(OXLINT_ARGS)
	pylint $(PYLINT_ARGS)
	ruff check $(RUFF_CHECK_ARGS)
	mypy $(MYPY_ARGS)
	python utils/xcstringslint.py Common/Localizable.xcstrings

lint-fix:
	python utils/xcstringslint.py --fix Common/Localizable.xcstrings

periphery:
	periphery scan $(PERIPHERY_ARGS)

spell-check:
	codespell $(CODESPELL_ARGS) $(CODE_DIRS) $(PYTHON_DIRS)

test:
	$(MAKE) $(TEST_MAKE_ARGS) test

test-stability:
	$(MAKE) $(TEST_MAKE_ARGS) stability

test-stability-watch:
	$(MAKE) $(TEST_MAKE_ARGS) stability-watch

test-generate-device-settings-clipboard:
	$(MAKE) $(TEST_MAKE_ARGS) generate-device-settings-clipboard

test-generate-device-settings-stdout:
	@$(MAKE) --no-print-directory --silent $(TEST_MAKE_ARGS) generate-device-settings-stdout

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
