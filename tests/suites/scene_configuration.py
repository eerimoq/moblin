from ..utils.generate_device_settings import CameraPosition
from ..utils.generate_device_settings import SceneName
from ..utils.generate_device_settings import WidgetType
from ..utils.generate_device_settings import scene_widget_settings
from ..utils.generate_device_settings import text_widget_settings
from ..utils.generate_device_settings import uuid
from ..utils.moblin import Moblin
from ..utils.test_case import TestCase


class SceneConfiguration(TestCase):
    """Create, update, reorder and delete scenes and widgets, and read media, over remote control."""

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
        self.editor_options()
        self.scenes_and_widgets()
        self.widget_image()
        self.alert_media()

    def editor_options(self):
        canvas_size = self.moblin.get_state()["canvasSize"]
        self.assert_true(canvas_size["width"] > 0 and canvas_size["height"] > 0)
        self.assert_in(self.moblin.get_state()["mirrorFrontCameraOnStream"], [True, False])
        options = self.moblin.get_editor_options()
        self.assert_true(len(options["fonts"]) > 0)
        self.assert_in("System", [font["family"] for font in options["fonts"]] + ["System"])
        for key in [
            "luts",
            "scoreboardPlayers",
            "webRemote",
            "workoutDevices",
            "streamDeckLayouts",
            "appleVoices",
        ]:
            self.assert_in(key, options)
        player_id = uuid()
        self.assert_in("ok", self.moblin.set_scoreboard_players([{"id": player_id, "name": "Remote player"}]))
        self.assert_equal(
            [player["id"].upper() for player in self.moblin.get_editor_options()["scoreboardPlayers"]],
            [player_id],
        )
        self.assert_in("error", self.moblin.set_scoreboard_players([{"id": player_id}, {"id": player_id}]))
        self.assert_in("ok", self.moblin.set_scoreboard_players([]))

    def widget_image(self):
        widget_id = uuid()
        self.assert_in(
            "ok",
            self.moblin.create_widget(
                {"id": widget_id, "name": "Remote image", "type": WidgetType.IMAGE, "enabled": True}
            ),
        )
        self.assert_equal(self.moblin.get_widget_image(widget_id), None)
        self.assert_equal(self.moblin.get_widget_image(uuid()), None)
        self.assert_in("ok", self.moblin.delete_widget(widget_id))

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

    def alert_media(self):
        gallery = self.moblin.get_alerts_media_gallery()
        self.assert_true(self.moblin.get_alert_media(gallery["bundledSounds"][0]["id"]) is not None)
        self.assert_equal(self.moblin.get_alert_media(uuid()), None)
        self.assert_in("error", self.moblin.delete_alert_media(gallery["bundledImages"][0]["id"]))
        self.assert_in("error", self.moblin.delete_alert_media(uuid()))


def tests(moblin: Moblin):
    return [SceneConfiguration(moblin)]
