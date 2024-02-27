all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat --maxwidth 110 Moblin
	swiftformat --maxwidth 110 "Moblin Watch"

style-check:
	swiftformat --maxwidth 110 --lint Moblin
	swiftformat --maxwidth 110 --lint "Moblin Watch"

lint:
	swiftlint lint --strict Moblin
	swiftlint lint --strict "Moblin Watch"

periphery:
	periphery scan

auto-translate:
	python3 utils/translate.py Moblin/Localizable.xcstrings

pack-exported-localizations:
	cd Moblin\ Localizations && for f in * ; do python3 ../utils/xliff.py $$f/Localized\ Contents/*.xliff && zip -r $$f.zip $$f ; done
