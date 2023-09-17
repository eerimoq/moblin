all:
	$(MAKE) style
	$(MAKE) lint

style:
	swiftformat Mobs --maxwidth 90 --lint

lint:
	swiftlint lint --strict Mobs
