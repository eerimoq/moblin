FORMAT_ARGS=--maxwidth 110 --swiftversion 5
LINT_ARGS=--strict --quiet

all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat $(FORMAT_ARGS) Common
	swiftformat $(FORMAT_ARGS) Moblin
	swiftformat $(FORMAT_ARGS) "Moblin Watch"
	swiftformat $(FORMAT_ARGS) "Moblin Widget"

style-check:
	swiftformat $(FORMAT_ARGS) --lint Common
	swiftformat $(FORMAT_ARGS) --lint Moblin
	swiftformat $(FORMAT_ARGS) --lint "Moblin Watch"
	swiftformat $(FORMAT_ARGS) --lint "Moblin Widget"

lint:
	swiftlint lint $(LINT_ARGS) Common
	swiftlint lint $(LINT_ARGS) Moblin
	swiftlint lint $(LINT_ARGS) "Moblin Watch"
	swiftlint lint $(LINT_ARGS) "Moblin Widget"

periphery:
	periphery scan

auto-translate:
	python3 utils/translate.py Common/Localizable.xcstrings

pack-exported-localizations:
	cd Moblin\ Localizations && for f in * ; do python3 ../utils/xliff.py $$f/Localized\ Contents/*.xliff && zip -r $$f.zip $$f ; done
