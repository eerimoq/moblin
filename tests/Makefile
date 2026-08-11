CONFIG_TOML ?= config.toml

SHELL = /usr/bin/env bash

test:
	python test.py $(CONFIG_TOML) $(TEST_ARGS)

stability:
	python stability.py $(CONFIG_TOML) $(TEST_ARGS)

stability-watch:
	python watch.py grid

generate-device-settings-clipboard:
	python generate_device_settings.py $(CONFIG_TOML)

generate-device-settings-stdout:
	@python generate_device_settings.py --force-stdout $(CONFIG_TOML)
