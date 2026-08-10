CONFIG_TOML ?= config.toml

SHELL = /usr/bin/env bash

test: prepare
	rm -f logs/test.log
	python test.py $(CONFIG_TOML) $(TEST_ARGS)

stability: prepare
	rm -f logs/stability.log
	python stability.py $(CONFIG_TOML) $(TEST_ARGS)

prepare:
	rm -rf files
	mkdir -p files

generate-device-settings-clipboard:
	python generate_device_settings.py $(CONFIG_TOML)

generate-device-settings-stdout:
	@python generate_device_settings.py --force-stdout $(CONFIG_TOML)
