all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat --maxwidth 90 Mobs
	swiftformat --maxwidth 90 --lint Mobs

lint:
	swiftlint lint --strict Mobs

periphery:
	periphery scan
