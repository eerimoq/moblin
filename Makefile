all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat --maxwidth 110 Common
	swiftformat --maxwidth 110 Moblin
	swiftformat --maxwidth 110 "Moblin Watch"
	swiftformat --maxwidth 110 "Moblin Widget"

style-check:
	swiftformat --maxwidth 110 --lint Common
	swiftformat --maxwidth 110 --lint Moblin
	swiftformat --maxwidth 110 --lint "Moblin Watch"
	swiftformat --maxwidth 110 --lint "Moblin Widget"

lint:
	swiftlint lint --strict Common
	swiftlint lint --strict Moblin
	swiftlint lint --strict "Moblin Watch"
	swiftlint lint --strict "Moblin Widget"

periphery:
	periphery scan

auto-translate:
	python3 utils/translate.py Moblin/Localizable.xcstrings

pack-exported-localizations:
	cd Moblin\ Localizations && for f in * ; do python3 ../utils/xliff.py $$f/Localized\ Contents/*.xliff && zip -r $$f.zip $$f ; done
