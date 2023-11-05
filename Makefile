all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat --maxwidth 90 Moblin

style-check:
	swiftformat --maxwidth 90 --lint Moblin

lint:
	swiftlint lint --strict Moblin

periphery:
	periphery scan
