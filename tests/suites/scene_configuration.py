import tempfile
from pathlib import Path

from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import WidgetType
from ..utils.generate_device_settings import download_model
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import text_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase
from ..utils.utils import write_png

PNG_TUBER_MODEL_NAME = "moblin.save"
V_TUBER_MODEL_NAME = "AliciaSolid.vrm"


class SceneConfiguration(TestCase):
    """Create, update, reorder and delete scenes, widgets and media over remote control."""

    def setup(self):
        self.moblin.import_settings(overrides={})

    def _scenes(self) -> dict[str, dict]:
        return {scene["id"].upper(): scene for scene in self.moblin.get_scenes()}

    def _widgets(self) -> dict[str, dict]:
        return {widget["id"].upper(): widget for widget in self.moblin.get_widgets()}

    def _front_scene_id(self) -> str:
        for scene in self.moblin.get_scenes():
            if scene["name"] == SceneName.FRONT:
                return scene["id"]
        raise Exception("Front scene not found")

    def run(self):
        self.video_sources()
        self.scenes_and_widgets()
        self.tuber_models()
        self.alert_media()

    def video_sources(self):
        video_sources = self.moblin.get_video_sources()
        self.assert_in(CameraPosition.NONE, [video_source["position"] for video_source in video_sources])

    def scenes_and_widgets(self):
        widget_id = uuid()
        scene_id = uuid()
        widget = text_widget_settings("Remote text", widget_id, {"formatString": "{time}"})
        self.assert_in("ok", self.moblin.create_widget(widget))
        self.assert_in("error", self.moblin.create_widget(widget))
        scene = {
            "id": scene_id,
            "name": "Remote",
            "cameraPosition": CameraPosition.BACK,
            "enabled": True,
            "widgets": [scene_widget_settings(widget_id, x=10, y=10, size=50)],
        }
        self.assert_in("ok", self.moblin.create_scene(scene))
        self.assert_in("error", self.moblin.create_scene(scene))
        self.assert_equal(self._scenes()[scene_id]["name"], "Remote")
        self.assert_equal(self._scenes()[scene_id]["widgets"][0]["widgetId"].upper(), widget_id)
        self.assert_equal(self._widgets()[widget_id]["text"]["formatString"], "{time}")
        self.moblin.set_scene_id(scene_id)
        self.moblin.wait_for_scene(scene_id)
        self.assert_in("ok", self.moblin.update_scene({**scene, "name": "Renamed"}))
        self.assert_equal(self._scenes()[scene_id]["name"], "Renamed")
        self.assert_in("error", self.moblin.update_scene({**scene, "id": uuid()}))
        widget["text"] = {"formatString": "{date}"}
        self.assert_in("ok", self.moblin.update_widget(widget))
        self.assert_equal(self._widgets()[widget_id]["text"]["formatString"], "{date}")
        self.assert_in("error", self.moblin.update_widget({**widget, "id": uuid()}))
        scene_ids = [scene["id"] for scene in self.moblin.get_scenes()]
        self.assert_equal(len(scene_ids), 2)
        self.assert_in("ok", self.moblin.reorder_scenes(list(reversed(scene_ids))))
        self.assert_equal([scene["id"] for scene in self.moblin.get_scenes()], list(reversed(scene_ids)))
        self.assert_in("error", self.moblin.reorder_scenes(scene_ids[:1]))
        self.assert_in("ok", self.moblin.reorder_widgets([widget_id]))
        self.assert_in("error", self.moblin.reorder_widgets([uuid()]))
        self.assert_in("ok", self.moblin.delete_widget(widget_id))
        self.assert_not_in(widget_id, self._widgets())
        self.assert_equal(self._scenes()[scene_id]["widgets"], [])
        self.assert_in("error", self.moblin.delete_widget(widget_id))
        self.assert_in("ok", self.moblin.delete_scene(scene_id))
        self.assert_not_in(scene_id, self._scenes())
        self.assert_in("error", self.moblin.delete_scene(scene_id))
        self.moblin.wait_for_scene(self._front_scene_id())

    def tuber_models(self):
        png_tuber_model_id = uuid()
        self.assert_in(
            "ok", self.moblin.set_png_tuber_model(png_tuber_model_id, download_model(PNG_TUBER_MODEL_NAME))
        )
        png_tuber_widget_id = uuid()
        self.assert_in(
            "ok",
            self.moblin.create_widget(
                {
                    "id": png_tuber_widget_id,
                    "name": "PNGTuber",
                    "type": WidgetType.PNG_TUBER,
                    "enabled": True,
                    "pngTuber": {
                        "id": png_tuber_model_id,
                        "cameraPosition": CameraPosition.FRONT,
                        "modelName": PNG_TUBER_MODEL_NAME,
                    },
                }
            ),
        )
        v_tuber_model_id = uuid()
        self.assert_in(
            "ok", self.moblin.set_vtuber_model(v_tuber_model_id, "VRM", download_model(V_TUBER_MODEL_NAME))
        )
        v_tuber_widget_id = uuid()
        self.assert_in(
            "ok",
            self.moblin.create_widget(
                {
                    "id": v_tuber_widget_id,
                    "name": "VTuber",
                    "type": WidgetType.V_TUBER,
                    "enabled": True,
                    "vTuber": {
                        "id": v_tuber_model_id,
                        "cameraPosition": CameraPosition.FRONT,
                        "modelName": V_TUBER_MODEL_NAME,
                    },
                }
            ),
        )
        self.assert_in("ok", self.moblin.delete_widget(png_tuber_widget_id))
        self.assert_in("ok", self.moblin.delete_widget(v_tuber_widget_id))

    def alert_media(self):
        media = {"id": uuid(), "name": "Remote image"}
        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "image.png"
            write_png(image, 2, 2, bytes([255, 0, 0, 255] * 4))
            self.assert_in("ok", self.moblin.set_alert_image(media, image))
        gallery = self.moblin.get_alerts_media_gallery()
        self.assert_in(media["id"], [item["id"].upper() for item in gallery["customImages"]])
        self.assert_in("error", self.moblin.delete_alert_media(gallery["bundledImages"][0]["id"]))
        self.assert_in("ok", self.moblin.delete_alert_media(media["id"]))
        gallery = self.moblin.get_alerts_media_gallery()
        self.assert_not_in(media["id"], [item["id"].upper() for item in gallery["customImages"]])
        self.assert_in("error", self.moblin.delete_alert_media(media["id"]))


def tests(moblin: Moblin):
    return [SceneConfiguration(moblin)]
