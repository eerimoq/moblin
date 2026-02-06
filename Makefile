SWIFTFORMAT_ARGS=--maxwidth 110 --swiftversion 5 --exclude Moblin/Integrations/Tesla/Protobuf --disable docComments
SWIFTLINT_ARGS=--strict --quiet
OXFMT_ARGS="Moblin/RemoteControl/Web"
OXLINT_ARGS="Moblin/RemoteControl/Web"
PERIPHERY_ARGS=--index-exclude "Moblin/Integrations/Tesla/Protobuf/*" \
		--index-exclude "**/PrepareLicenseList/**" \
		--disable-update-check
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
	oxfmt $(OXFMT_ARGS)

style-check:
	swiftformat $(CODE_FOLDERS) $(SWIFTFORMAT_ARGS) --lint
	oxfmt $(OXFMT_ARGS) --check

lint:
	swiftlint lint $(SWIFTLINT_ARGS) $(CODE_FOLDERS)
	oxlint $(OXLINT_ARGS)

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
