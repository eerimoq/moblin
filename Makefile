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
	test \
	utils
BLACK_ARGS = $(PYTHON_DIRS)
PERIPHERY_ARGS = \
	--index-exclude "Moblin/Integrations/Tesla/Protobuf/*" \
	--index-exclude "**/PrepareLicenseList/**" \
	--disable-update-check
CODESPELL_ARGS = \
	--skip "*.xcstrings,libsrt.xcframework,VoicesView.swift,TextAlignerSuite.swift,Web,node_modules,package-lock.json,*.log" \
	--ignore-words-list "inout,froms,soop,medias,deactive,upto,datas,ro,lightyears"
PYLINT_ARGS = \
	--disable missing-function-docstring \
	--disable missing-module-docstring \
	--disable too-many-nested-blocks \
	--disable broad-exception-caught \
	--disable broad-exception-raised \
	--disable too-many-locals \
	--disable duplicate-code \
	--disable missing-class-docstring \
	--disable line-too-long \
	--recursive yes \
	$(PYTHON_DIRS)

CODE_DIRS += "Common"
CODE_DIRS += "Moblin"
CODE_DIRS += "Moblin Watch"
CODE_DIRS += "Moblin Widget"
CODE_DIRS += "Moblin Live Activity"
CODE_DIRS += "Moblin Screen Recording"
CODE_DIRS += "MoblinTests"
CODE_DIRS += "WebRemoteControlFrontend"

SHELL = /usr/bin/env bash

.PHONY: test

default:

style:
	swiftformat $(CODE_DIRS) $(SWIFTFORMAT_ARGS)
	oxfmt $(OXFMT_ARGS)
	black $(BLACK_ARGS) || true

style-check:
	swiftformat $(CODE_DIRS) $(SWIFTFORMAT_ARGS) --lint
	oxfmt $(OXFMT_ARGS) --check
	black $(BLACK_ARGS) --check

lint:
	swiftlint lint $(SWIFTLINT_ARGS) $(CODE_DIRS)
	oxlint $(OXLINT_ARGS)
	pylint $(PYLINT_ARGS) || true
	python3 utils/xcstringslint.py Common/Localizable.xcstrings

lint-fix:
	python3 utils/xcstringslint.py --fix Common/Localizable.xcstrings

periphery:
	periphery scan $(PERIPHERY_ARGS)

spell-check:
	codespell $(CODESPELL_ARGS) $(CODE_DIRS) $(PYTHON_DIRS)

test:
	rm -rf test/logs test/mediamtx.log test/Recording_*.mp4
	cd test && python main.py config.toml

test-generate-device-settings:
	rm -f test/*-settings.json
	cd test && python generate_device_settings.py config.toml && cat *-settings.json | pbcopy

machine-translate:
	python3 utils/translate.py Common/Localizable.xcstrings

pack-exported-localizations:
	cd Moblin\ Localizations && \
	for f in * ; do \
	    python3 ../utils/xliff.py $$f/Localized\ Contents/*.xliff && \
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
