SWIFTFORMAT_ARGS=--maxwidth 120 --swiftversion 5 --exclude Moblin/Integrations/Tesla/Protobuf --quiet
PRETTIER_ARGS=--log-level silent "Moblin/**/*.js"
SWIFTLINT_ARGS=--strict --quiet
CODESPELL_ARGS=--skip "*.xcstrings,libsrt.xcframework,VoicesView.swift,TextAlignerSuite.swift" \
		 --ignore-words-list "inout,froms,soop,medias,deactive,upto,datas,ro"

all:

style:
	swiftformat $(SWIFTFORMAT_ARGS) "Common"
	swiftformat $(SWIFTFORMAT_ARGS) "Moblin"
	swiftformat $(SWIFTFORMAT_ARGS) "Moblin Watch"
	swiftformat $(SWIFTFORMAT_ARGS) "Moblin Widget"
	swiftformat $(SWIFTFORMAT_ARGS) "Moblin Screen Recording"
	swiftformat $(SWIFTFORMAT_ARGS) "MoblinTests"
	prettier $(PRETTIER_ARGS) --write

style-check:
	swiftformat $(SWIFTFORMAT_ARGS) --lint "Common"
	swiftformat $(SWIFTFORMAT_ARGS) --lint "Moblin"
	swiftformat $(SWIFTFORMAT_ARGS) --lint "Moblin Watch"
	swiftformat $(SWIFTFORMAT_ARGS) --lint "Moblin Widget"
	swiftformat $(SWIFTFORMAT_ARGS) --lint "Moblin Screen Recording"
	swiftformat $(SWIFTFORMAT_ARGS) --lint "MoblinTests"
	prettier $(PRETTIER_ARGS) --check

lint:
	swiftlint lint $(SWIFTLINT_ARGS) "Common"
	swiftlint lint $(SWIFTLINT_ARGS) "Moblin"
	swiftlint lint $(SWIFTLINT_ARGS) "Moblin Watch"
	swiftlint lint $(SWIFTLINT_ARGS) "Moblin Widget"
	swiftlint lint $(SWIFTLINT_ARGS) "Moblin Screen Recording"
	swiftlint lint $(SWIFTLINT_ARGS) "MoblinTests"

spell-check:
	codespell $(CODESPELL_ARGS) "Common"
	codespell $(CODESPELL_ARGS) "Moblin"
	codespell $(CODESPELL_ARGS) "Moblin Watch"
	codespell $(CODESPELL_ARGS) "Moblin Widget"
	codespell $(CODESPELL_ARGS) "Moblin Screen Recording"
	codespell $(CODESPELL_ARGS) "MoblinTests"

machine-translate:
	python3 utils/translate.py Common/Localizable.xcstrings

pack-exported-localizations:
	cd Moblin\ Localizations && \
	for f in * ; do \
	    python3 ../utils/xliff.py $$f/Localized\ Contents/*.xliff && \
	    zip -qr $$f.zip $$f && \
	    rm -rf $$f ; \
	done
