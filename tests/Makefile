SHELL = /usr/bin/env bash

test:
	python test.py $(TEST_ARGS)

stability:
	python stability.py $(TEST_ARGS)

stability-watch:
	python watch.py grid

generate-device-settings-clipboard:
	python generate_device_settings.py

generate-device-settings-stdout:
	@python generate_device_settings.py --force-stdout
