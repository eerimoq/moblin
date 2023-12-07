|app-store|_

Moblin - IRL Streaming
======================

A free iOS app for IRL streaming. Mainly targeting `Twitch`_, but can
stream to `YouTube`_, `Kick`_, `Facebook`_ and `OBS Studio`_ as well
(and probably more).

.. image:: https://github.com/eerimoq/moblin/raw/main/docs/main.jpg
           
Discord: https://discord.gg/nt3UwHqbMM

Github: https://github.com/eerimoq/moblin

TestFlight: https://testflight.apple.com/join/PDpxEaGh

Features
========

- Stream using RTMP, RTMPS, SRT or SRTLA to any platform that supports
  them.

- H.264/AVC and H.265/HEVC video codecs.

- Up to 1080p and 60 FPS.

- SRTLA.

  - Can use one cellular, one WiFi and one Ethernet connection
    simultaneously. Often called bonding.

  - Upload statistics per active connection.

- Twitch integration.

  - Number of viewers.

  - Chat.

- Kick integration.

  - Chat.

- YouTube integration.

  - Scuffed chat.

- AfreecaTv integration.

  - Scuffed chat.

- Basic scenes.

  - Image widget. Show an image on stream.

  - Time widget. Show local (phone) time on stream.

  - Browser widget (not yet fully functional). Show a web page on
    stream.

- Back or front camera.

  - Front camera mirrored on screen for natural experience.

- Back, front, bottom or external mic.

  - Automatically changes to external mic when connected.

- Video stabilization.

- Zoom.

  - Pinch-to-zoom.

  - Configurable presets.

- Back camera lens selection.

- Localization. Supports many languages, for example English, French,
  German, Spanish, Polish, Chinese (Simplified) and Swedish.

- Tap screen for manual focus.

  - Return to auto focus with long press.

- Stream connection status and uptime.

- Video effects.

  - Grayscale.

  - Movie. Paint top and bottom of 16:9 video black to look like
    2.35:1.

  - Seipa.

  - Noise reduction.

  - Random. A single effect that applies a random effect.

  - Triple. Show center of image three times. Experimental.

- Chat styling (colors, background, shadow, bold).

  - Twitch, BTTV, FFZ and 7TV emotes.

- Cosmetics.

  - Select Moblin icon to show in app and on home screen.

  - Optionally purchase additional Moblin icons to support developers.

- Configure stream resolution, FPS, video codec, bitrate and more.

- Configurable bitrate presets.

- Torch.

- Mute audio.

- Deep link settings (moblin://).

- Configure maximum screen FPS (to save energy).

- Landscape only.

  - Both 0 and 180 degrees orientation. Video always with gravity down
    (never upside down).

- Battery indicator. Optionally with percentage.

ToDo
====

- Improve the browser widget.

- Fix start app "upside down".

Ideas/plan
==========

- Show two cameras at the same time.

- Use lossy video format? More effecient?

- Always receive sampels from all mics for smoother transition between mics?

- Button to show black screen.

- Reduce brightness when thermal state is critical.

- A list of usernames whos messages will not get displayed on screen.

- Rework zoom. Fine tune similar to builtin camera app.

- Audio filters. For example volume limiter.

  - An adjustable gain would be nice, then limiter (to keep audio from
    clipping), and a noise gate would be my top 3 requested audio
    filters when you have the time. I think that would be the same
    order in terms of complexity to implement as well.

- Button to turn maximum screen FPS on and off. Or possibly "low
  power" mode?

- Use external UVC camera. Looks like iOS 17 supports them.

- Use multiple mics at the same time?

- Reintroduce settings in portrait.

- Take picture.

- OPUS audio codec? https://github.com/alta/swift-opus

- Optionally do not automatically start using external mic is plugged
  in.

- Advanced settings toggle.

- Non-mirrored widgets locally when using front camera.

- Add Twitch/Kick Icons next to chat messages depending on which
  platform the message came from.

- Toggles to enable/disable "Go live" and "Stop" confirmations. Per
  stream?

- RTMP server for external video and audio?

- Multiple Ethernet connections simultaneously?

- Automatically go live when starting app, if configured for selected
  stream setting. Probably a good idea to go live again when entering
  foregound if was live when entering background

- Lookup Twitch channel id from channel name. Possibly login to
  Twitch.

- Play music and short sound samples.

- Record to disk.

- Something that is important for professional streamers: Ad
  management. There are new endpoints to get and snooze the next ad
  schedule. No app uses it afaik yet.

  - https://dev.twitch.tv/docs/api/reference/#get-ad-schedule

Import settings using moblin:// (custom URL)
============================================

An example creating a new stream is

.. code-block::

   moblin://?{"streams":[{"name":"BELABOX%20UK","url":"srtla://uk.srt.belabox.net:5000?streamid=9812098rh9hf8942hid","video":{"codec":"H.265/HEVC"}}]}

where the URL decoded pretty printed JSON blob is

.. code-block:: json

   {
     "streams": [
       {
         "name": "BELABOX UK",
         "url": "srtla://uk.srt.belabox.net:5000?streamid=9812098rh9hf8942hid",
         "video": {
           "codec": "H.265/HEVC"
         }
       }
     ]
   }

Format: ``moblin://?<URL encoded JSON blob>``

The ``MoblinSettingsUrl`` class in `MoblinSettingsUrl.swift`_ defines
the JSON blob format. Class members are JSON object keys. Members with
``?`` after the type are optional. Some types are defined in
`Settings.swift`_.

Ideas
=====

Examples of text widgets
------------------------

Default SRT stats
^^^^^^^^^^^^^^^^^

Configured text:

.. code-block:: text

   {srtStats}

Rendered on stream:

.. code-block:: text

   pktRetransTotal: 524
   pktRecvNAKTotal: 203
   pktSndDropTotal: 2
   msRTT: 42.47
   pktFlightSize: 12
   pktSndBuf: 2

Clock
^^^^^

Configured text:

.. code-block:: text

   {clock}

Rendered on stream:

.. code-block:: text

   12:32:51

Clock and two SRT stats
^^^^^^^^^^^^^^^^^^^^^^^

Configured text:

.. code-block:: text

   clock: {clock}
   msRTT: {srtStatsMsRtt}
   pktFlightSize: {srtStatsPktFlightSize}

Rendered on stream:

.. code-block:: text

   clock: 12:32:51
   msRTT: 33.1
   pktFlightSize: 3

Similar software
================

- https://irlpro.app/

- Twitch app.

- https://softvelum.com/larix/ios/

.. _OBS Studio: https://obsproject.com

.. _go: https://go.dev

.. _SRTLA: https://github.com/BELABOX/srtla

.. _Twitch: https://twitch.tv

.. _YouTube: https://youtube.com

.. _Kick: https://kick.com

.. _Facebook: https://facebook.com

.. _TestFlight: https://testflight.apple.com/join/PDpxEaGh

.. _MoblinSettingsUrl.swift: https://github.com/eerimoq/moblin/blob/main/Moblin/MoblinSettingsUrl.swift

.. _Settings.swift: https://github.com/eerimoq/moblin/blob/main/Moblin/Settings.swift

.. |app-store| image:: https://github.com/eerimoq/moblin/raw/main/docs/app-store.svg
  :width: 100
.. _app-store: https://apps.apple.com/us/app/moblin/id6466745933
