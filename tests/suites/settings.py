import tempfile
import zipfile
from pathlib import Path

from ..utils.generate_device_settings import SceneName
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase


class SettingsImportWithoutSettingsFile(TestCase):
    """Import a settings archive without settings.json and verify that the import fails."""

    def setup(self):
        self.moblin.import_settings(overrides={})

    def run(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "settings.zip"
            with zipfile.ZipFile(archive, "w") as zip_file:
                zip_file.writestr("other.json", "{}")
            result = self.moblin.import_settings_archive(archive)
        self.assert_in("error", result)
        self.moblin.set_scene(SceneName.FRONT)


def tests(moblin: Moblin):
    return [SettingsImportWithoutSettingsFile(moblin)]
