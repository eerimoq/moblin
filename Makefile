all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat --maxwidth 110 Moblin

style-check:
	swiftformat --maxwidth 110 --lint Moblin

lint:
	swiftlint lint --strict Moblin

periphery:
	periphery scan
