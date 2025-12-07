FORMAT_ARGS=--maxwidth 120 --swiftversion 5 --exclude Moblin/Integrations/Tesla/Protobuf
LINT_ARGS=--strict --quiet

all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat $(FORMAT_ARGS) "Common"
	swiftformat $(FORMAT_ARGS) "Moblin"
	swiftformat $(FORMAT_ARGS) "Moblin Watch"
	swiftformat $(FORMAT_ARGS) "Moblin Widget"
	swiftformat $(FORMAT_ARGS) "Moblin Screen Recording"
	swiftformat $(FORMAT_ARGS) "MoblinTests"
	prettier --write "Moblin/**/*.js"

style-check:
	swiftformat $(FORMAT_ARGS) --lint "Common"
	swiftformat $(FORMAT_ARGS) --lint "Moblin"
	swiftformat $(FORMAT_ARGS) --lint "Moblin Watch"
	swiftformat $(FORMAT_ARGS) --lint "Moblin Widget"
	swiftformat $(FORMAT_ARGS) --lint "Moblin Screen Recording"
	swiftformat $(FORMAT_ARGS) --lint "MoblinTests"
	prettier --check "Moblin/**/*.js"

lint:
	swiftlint lint $(LINT_ARGS) "Common"
	swiftlint lint $(LINT_ARGS) "Moblin"
	swiftlint lint $(LINT_ARGS) "Moblin Watch"
	swiftlint lint $(LINT_ARGS) "Moblin Widget"
	swiftlint lint $(LINT_ARGS) "Moblin Screen Recording"
	swiftlint lint $(LINT_ARGS) "MoblinTests"

machine-translate:
	python3 utils/translate.py Common/Localizable.xcstrings

pack-exported-localizations:
	cd Moblin\ Localizations && \
	for f in * ; do \
	    python3 ../utils/xliff.py $$f/Localized\ Contents/*.xliff && \
	    zip -qr $$f.zip $$f && \
	    rm -rf $$f ; \
	done
