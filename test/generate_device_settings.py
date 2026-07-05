import argparse
import json
import tomllib
from pathlib import Path

import pyperclip

from utils.utils import format_generic_stream_url_stream_name

RTMP_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1385"
RTMP_TALKBACK_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1386"
RTSP_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1387"
RIST_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1388"
SRT_STREAM_ID = "F3868489-D301-422D-A7DD-335572CA1389"
FRONT_VIDEO_SOURCE_WIDGET_ID = "F3868489-D301-422D-A7DD-335572CA1311"
BROWSER_WIDGET_PERIODIC_AUDIO_AND_VIDEO_ID = "F3868489-D301-422D-A7DD-335572CA1312"
BROWSER_WIDGET_AUDIO_AND_VIDEO_ONLY_ID = "F3868489-D301-422D-A7DD-335572CA1313"
BROWSER_WIDGET_AUDIO_ONLY_ID = "F3868489-D301-422D-A7DD-335572CA1314"
BROWSER_WIDGET_LOCAL_ONLY_ID = "F3868489-D301-422D-A7DD-335572CA1315"


def create_settings(config):
    general = config["general"]
    tester_ip_address = general["tester-ip-address"]
    streams = [
        {
            "name": "RTMP",
            "enabled": True,
            "bitrateRateControl": "CBR",
            "url": f"rtmp://{tester_ip_address}:1935/test",
            "rtmp": {"adaptiveBitrateEnabled": False},
        },
        {
            "name": "SRT",
            "bitrateRateControl": "CBR",
            "url": f"srt://{tester_ip_address}:8890?streamid=publish:test",
            "srt": {"adaptiveBitrateEnabled": False},
            "bitrate": 50_000_000,
        },
        {
            "name": "SRT 5Mbps",
            "bitrateRateControl": "CBR",
            "url": f"srt://{tester_ip_address}:8890?streamid=publish:test",
            "srt": {"adaptiveBitrateEnabled": False},
            "bitrate": 5_000_000,
        },
        {
            "name": "SRT encrypted",
            "bitrateRateControl": "CBR",
            "url": f"srt://{tester_ip_address}:8890?streamid=publish:test&passphrase=1234567890",
            "srt": {"adaptiveBitrateEnabled": False, "implementation": "Official"},
            "bitrate": 5_000_000,
        },
        {
            "name": "Multi RTMP",
            "bitrateRateControl": "CBR",
            "url": f"rtmp://{tester_ip_address}:1935/test1",
            "rtmp": {"adaptiveBitrateEnabled": False},
            "multiStreaming": {
                "destinations": [
                    {
                        "name": "Test 2",
                        "url": f"rtmp://{tester_ip_address}:1935/test2",
                        "enabled": True,
                    },
                    {
                        "name": "Test 3",
                        "url": f"rtmp://{tester_ip_address}:1935/test3",
                        "enabled": True,
                    },
                ]
            },
        },
        {"name": "Record H.264", "recording": {"videoCodec": "H.264/AVC"}},
        {"name": "Record H.265", "recording": {"videoCodec": "H.265/HEVC"}},
    ]
    for number, generic_stream_url in enumerate(general["generic-stream-urls"], 1):
        streams.append(
            {
                "name": format_generic_stream_url_stream_name(
                    number, generic_stream_url
                ),
                "bitrateRateControl": "CBR",
                "url": generic_stream_url,
                "codec": "H.264/AVC",
                "bitrate": 5_000_000,
            }
        )
    return {
        "streams": streams,
        "scenes": [
            {"name": "Front", "cameraPosition": "Front", "enabled": True},
            {"name": "Screen", "cameraPosition": "Screen capture", "enabled": True},
            {
                "name": "RTMP",
                "cameraPosition": "RTMP",
                "rtmpCameraId": RTMP_STREAM_ID,
                "enabled": True,
            },
            {
                "name": "RTSP",
                "cameraPosition": "RTSP",
                "rtspCameraId": RTSP_STREAM_ID,
                "enabled": True,
            },
            {
                "name": "RIST",
                "cameraPosition": "RIST",
                "ristCameraId": RIST_STREAM_ID,
                "enabled": True,
            },
            {
                "name": "SRT",
                "cameraPosition": "SRT(LA)",
                "srtlaCameraId": SRT_STREAM_ID,
                "enabled": True,
            },
            {
                "name": "PiP",
                "cameraPosition": "Back",
                "backCameraId": "com.apple.avfoundation.avcapturedevice.built-in_video:0",
                "widgets": [
                    {
                        "widgetId": FRONT_VIDEO_SOURCE_WIDGET_ID,
                        "alignment": "BottomRight",
                        "x": 0,
                        "y": 0,
                        "size": 50,
                        "migrated": True,
                        "migrated2": True,
                    }
                ],
                "enabled": True,
            },
            {
                "name": "Browser widgets",
                "cameraPosition": "Screen capture",
                "widgets": [
                    {
                        "widgetId": BROWSER_WIDGET_PERIODIC_AUDIO_AND_VIDEO_ID,
                        "alignment": "TopLeft",
                        "x": 0,
                        "y": 0,
                        "size": 100,
                        "migrated": True,
                        "migrated2": True,
                    },
                    {
                        "widgetId": BROWSER_WIDGET_AUDIO_AND_VIDEO_ONLY_ID,
                        "alignment": "TopLeft",
                        "x": 50,
                        "y": 0,
                        "size": 100,
                        "migrated": True,
                        "migrated2": True,
                    },
                    {
                        "widgetId": BROWSER_WIDGET_AUDIO_ONLY_ID,
                        "alignment": "TopLeft",
                        "x": 0,
                        "y": 50,
                        "size": 100,
                        "migrated": True,
                        "migrated2": True,
                    },
                    {
                        "widgetId": BROWSER_WIDGET_LOCAL_ONLY_ID,
                        "alignment": "TopLeft",
                        "x": 50,
                        "y": 50,
                        "size": 100,
                        "migrated": True,
                        "migrated2": True,
                    },
                ],
                "enabled": True,
            },
        ],
        "widgets": [
            {
                "id": FRONT_VIDEO_SOURCE_WIDGET_ID,
                "name": "Front",
                "type": "Video source",
                "videoSource": {
                    "cameraPosition": "Front",
                    "frontCameraId": "com.apple.avfoundation.avcapturedevice.built-in_video:1",
                },
            },
            {
                "id": BROWSER_WIDGET_PERIODIC_AUDIO_AND_VIDEO_ID,
                "name": "Browser periodic audio and video",
                "type": "Browser",
                "browser": {
                    "url": f"http://{tester_ip_address}:6967/BrowserWidgetHighFpsVideo.html",
                    "width": 1920,
                    "height": 1080,
                    "mode": "periodicAudioAndVideo",
                },
            },
            {
                "id": BROWSER_WIDGET_AUDIO_AND_VIDEO_ONLY_ID,
                "name": "Browser audio and video only",
                "type": "Browser",
                "browser": {
                    "url": f"http://{tester_ip_address}:6967/BrowserWidgetHighFpsVideo.html",
                    "width": 1920,
                    "height": 1080,
                    "mode": "audioAndVideoOnly",
                },
            },
            {
                "id": BROWSER_WIDGET_AUDIO_ONLY_ID,
                "name": "Browser audio only",
                "type": "Browser",
                "browser": {
                    "url": f"http://{tester_ip_address}:6967/BrowserWidgetHighFpsVideo.html",
                    "width": 1920,
                    "height": 1080,
                    "mode": "audioOnly",
                },
            },
            {
                "id": BROWSER_WIDGET_LOCAL_ONLY_ID,
                "name": "Browser local only",
                "type": "Browser",
                "browser": {
                    "url": f"http://{tester_ip_address}:6967/BrowserWidgetHighFpsVideo.html",
                    "width": 1920,
                    "height": 1080,
                    "localOnly": True,
                },
            },
        ],
        "remoteControl": {
            "server": {
                "enabled": True,
                "url": f"ws://{tester_ip_address}:{general["remote-control-port"]}",
            },
            "web": {"enabled": True, "port": 1180},
            "password": "1234",
        },
        "rtmpServer": {
            "enabled": True,
            "port": 11935,
            "streams": [
                {"id": RTMP_STREAM_ID, "name": "1", "streamKey": "1"},
                {
                    "id": RTMP_TALKBACK_STREAM_ID,
                    "name": "Talkback",
                    "streamKey": "talkback",
                },
            ],
        },
        "srtlaServer": {
            "enabled": True,
            "srtPort": 4000,
            "streams": [
                {
                    "id": SRT_STREAM_ID,
                    "name": "Test",
                    "streamId": "1",
                },
            ],
        },
        "rtspClient": {
            "streams": [
                {
                    "id": RTSP_STREAM_ID,
                    "name": "1",
                    "url": f"rtsp://{tester_ip_address}:8554/1",
                    "enabled": True,
                },
            ],
        },
        "ristServer": {
            "enabled": True,
            "port": 6500,
            "streams": [
                {"id": RIST_STREAM_ID, "name": "1", "virtualDestinationPort": 1}
            ],
        },
        "talkBack": {"enabled": True, "micId": f"{RTMP_TALKBACK_STREAM_ID} 0"},
        "verboseStatuses": True,
        "showAllSettings": True,
        "debug": {"logLevel": "Debug"},
        "show": {"stream": True, "cpu": True},
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--force-stdout", action="store_true")
    parser.add_argument("config_toml", type=Path)
    args = parser.parse_args()
    config = tomllib.loads(args.config_toml.read_text())
    settings = create_settings(config)
    settings = json.dumps(settings, indent=4)
    if args.force_stdout:
        print(settings)
    else:
        pyperclip.copy(settings)
        print("Settings copied to clipboard.")


main()
