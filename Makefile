SWIFTFORMAT_ARGS = \
	--maxwidth 110 \
	--swiftversion 5 \
	--exclude Moblin/Integrations/Tesla/Protobuf \
	--disable docComments \
	--ifdef no-indent
SWIFTLINT_ARGS = --strict --quiet
OXFMT_ARGS = "WebRemoteControlFrontend"
OXLINT_ARGS = "WebRemoteControlFrontend"
PERIPHERY_ARGS = \
	--index-exclude "Moblin/Integrations/Tesla/Protobuf/*" \
	--index-exclude "**/PrepareLicenseList/**" \
	--disable-update-check
CODESPELL_ARGS = \
	--skip "*.xcstrings,libsrt.xcframework,VoicesView.swift,TextAlignerSuite.swift,Web,node_modules,package-lock.json" \
	--ignore-words-list "inout,froms,soop,medias,deactive,upto,datas,ro"
PYLINT_ARGS = \
	--disable missing-function-docstring \
	--disable missing-module-docstring \
	--disable too-many-nested-blocks \
	--disable broad-exception-caught \
	--disable too-many-locals \
	--disable duplicate-code \
	--recursive yes \
	.

CODE_FOLDERS += "Common"
CODE_FOLDERS += "Moblin"
CODE_FOLDERS += "Moblin Watch"
CODE_FOLDERS += "Moblin Widget"
CODE_FOLDERS += "Moblin Live Activity"
CODE_FOLDERS += "Moblin Screen Recording"
CODE_FOLDERS += "MoblinTests"
CODE_FOLDERS += "WebRemoteControlFrontend"

SHELL = /usr/bin/env bash

default:

style:
	swiftformat $(CODE_FOLDERS) $(SWIFTFORMAT_ARGS)
	oxfmt $(OXFMT_ARGS)

style-check:
	swiftformat $(CODE_FOLDERS) $(SWIFTFORMAT_ARGS) --lint
	oxfmt $(OXFMT_ARGS) --check

lint:
	swiftlint lint $(SWIFTLINT_ARGS) $(CODE_FOLDERS)
	oxlint $(OXLINT_ARGS)
	python3 utils/xcstringslint.py Common/Localizable.xcstrings

pylint:
	pylint $(PYLINT_ARGS)

lint-fix:
	python3 utils/xcstringslint.py --fix Common/Localizable.xcstrings

periphery:
	periphery scan $(PERIPHERY_ARGS)

spell-check:
	codespell $(CODESPELL_ARGS) $(CODE_FOLDERS)

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
