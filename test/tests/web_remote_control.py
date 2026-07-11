from playwright.sync_api import sync_playwright

from utils.config import WEB_REMOTE_CONTROL_PORT
from utils.mediamtx import MediaMtx
from utils.moblin import Moblin
from utils.test_case import TestCase


class WebRemoteControlLive(TestCase):
    """Go live and end."""

    def run(self):
        self.moblin.set_scene("Front")
        with MediaMtx() as mediamtx:
            self.moblin.set_stream("RTMP")
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch()
                page = browser.new_page()
                page.goto(f"http://{self.moblin.ip_address}:{WEB_REMOTE_CONTROL_PORT}")
                live_toggle = page.get_by_text("Live", exact=True)
                self.assert_false(live_toggle.is_checked())
                live_toggle.click()
                page.get_by_role("button", name="OK").click()
                self.moblin.wait_for_bitrate(4_500_000, 5_500_000, None, 3_000_000)
                mediamtx.wait_for_rtmp_stream("test", 3_000_000)
                self.assert_true(live_toggle.is_checked())
                live_toggle.click()
                page.get_by_role("button", name="OK").click()
                self.wait_until(lambda: not live_toggle.is_checked())
                browser.close()


def tests(moblin: Moblin):
    return [
        WebRemoteControlLive(moblin),
    ]
