all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat --maxwidth 90 Moblin
	swiftformat --maxwidth 90 --lint Moblin

lint:
	swiftlint lint --strict Moblin

periphery:
	periphery scan
