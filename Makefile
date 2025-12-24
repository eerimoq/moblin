SWIFTFORMAT_ARGS=--maxwidth 110 --swiftversion 5 --exclude Moblin/Integrations/Tesla/Protobuf --quiet
PRETTIER_ARGS=--log-level silent "Moblin/**/*.js"
SWIFTLINT_ARGS=--strict --quiet
CODESPELL_ARGS=--skip "*.xcstrings,libsrt.xcframework,VoicesView.swift,TextAlignerSuite.swift" \
		 --ignore-words-list "inout,froms,soop,medias,deactive,upto,datas,ro"

CODE_FOLDERS += "Common"
CODE_FOLDERS += "Moblin"
CODE_FOLDERS += "Moblin Watch"
CODE_FOLDERS += "Moblin Widget"
CODE_FOLDERS += "Moblin Screen Recording"
CODE_FOLDERS += "MoblinTests"

all:

style:
	swiftformat $(CODE_FOLDERS) $(SWIFTFORMAT_ARGS)
	prettier $(PRETTIER_ARGS) --write

style-check:
	swiftformat $(CODE_FOLDERS) $(SWIFTFORMAT_ARGS) --lint
	prettier $(PRETTIER_ARGS) --check

lint:
	swiftlint lint $(SWIFTLINT_ARGS) $(CODE_FOLDERS)

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
