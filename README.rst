MOBS
====

A free iOS app for IRL streaming. Mainly targetting `Twitch`_, but can
stream to `YouTube`_, `Kick`_, `Facebook`_ and `OBS Studio`_ as well
(and probably more).

Not yet in App Store, but on `TestFlight`_!

.. image:: https://github.com/eerimoq/mobs/raw/main/Docs/main.jpg

Discord: https://discord.gg/nt3UwHqbMM

Github: https://github.com/eerimoq/mobs

TestFlight: https://testflight.apple.com/join/PDpxEaGh

This project is **not** part of `OBS`_. It's just the name that is
inspired by it.

Features
========

- Stream using RTMP, RTMPS, SRT or SRTLA to any platform that
  supportes them.

- H.264/AVC and H.265/HEVC video codecs.

- Up to 1080p and 60 FPS.

- SRTLA.

  - Can use one cellular, one WiFi and one Ethernet connection
    simultaneously.

  - Upload statistics per active connection.

- Twitch integration.

  - Number of viewers.

  - Chat.

- YouTube integration.

  - None.

- Kick integration.

  - Chat.

- Basic scenes.

  - Image widget. Show an image on stream.

  - Time widget. Show local (phone) time on stream.

  - Browser widget (not yet fully functional). Show a web page on
    stream.

- Back or front camera.

  - Front camera mirrored on screen for natural experience.

- Back, front or bottom mic.

- Video stabilization.

- Zoom.

  - Pinch-to-zoom.

  - Configurable presets.

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

- Cosmetics.

  - Select MOBS icon to show in app and on home screen.

- Configure stream resolution, FPS, video codec, bitrate and more.

- Configurable bitrate presets.

- Torch.

- Mute audio.

- Deep link settings (mobs://).

- Configure maximum screen FPS (to save energy).

- Landscape stream only.

ToDo
====

- Sometimes a stroboscope effect happens on screen.

- Improve the browser widget.

- Sometimes video freezes when changing settings or when enter/exit
  background mode. Looks like there is two sessions if changing stream
  from RTMP to SRT. Should only be one.

- Overlays are mirrored locally when using front camera. Ok, or needs
  change?

- Crash when calculating audio level.

Ideas/plan
==========

- Use external mic.

- Battery level as percentage.

- Optionally show black screen to save enxergy. Possible to turn off
  completely?

  - https://developer.apple.com/documentation/uikit/uiscreen

    - ``brightness`` and ``wantsSoftwareDimming``.

- Settings on half landscape screen so video can be seen when changing
  settings. Minimize button? Transparent?

- Toggles to enable/disable "Go live" and "Stop" confirmations. Per
  stream?

- Automatically go live when starting app, if configured for selected
  stream setting. Probably a good idea to go live again when entering
  foregound if was live when entering background

- Adaptive bitrate for SRT(LA).

  - Increase bitrate when RTT settles down?

  - Decrease bitrate when RTT increases?

  - Drop bitrate heavily when number of packets in flight is above a
    threshold?

  - Decrease bitrate when SRT NAKs are received?

  - Decrease bitrate if number of packets in flight exceeds number of
    packets needed for current bitrate?

- Zoom meter with lines indicating likely lens switches.

- Interactive local browser(s).

- Local horizon overlay.

- Local grid overlay? What is this used for?

- Safe margins local overlay? What is this used for?

- Show web page on stream and/or locally. Audio kinda important.

- Multiple Ethernet connections simultaneously?

- Snapshot button.

- Lookup Twitch channel id from channel name. Possibly login to
  Twitch.

- Audio only when bad connection.

- Emoji chat.

- Show two cameras at the same time.

- Bigger chat text? Bigger text in general?

- Preview buttons.

- Play music and short sound samples.

- Stream mobile games.

- Geolocation (with map?).

- Record to disk.

- LIDAR, altitude.

Import settings using mobs:// (custom URL)
==========================================

An example creating a new stream is

.. code-block::

   mobs://?{"streams":[{"name":"BELABOX%20UK","url":"srtla://uk.srt.belabox.net:5000?streamid=9812098rh9hf8942hid","video":{"codec":"H.265/HEVC"}}]}

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

Format: ``mobs://?<URL encoded JSON blob>``

The ``MobsSettingsUrl`` class in `MobsSettingsUrl.swift`_ defines the
JSON blob format. Class members are JSON object keys. Members with
``?`` after the type are optional. Some types are defined in
`Settings.swift`_.

Similar software
================

- https://irlpro.app/

- Twitch app.

- https://github.com/pedroSG94/RootEncoder-iOS

.. _OBS: https://obsproject.com

.. _OBS Studio: https://obsproject.com

.. _go: https://go.dev

.. _SRTLA: https://github.com/BELABOX/srtla

.. _Twitch: https://twitch.tv

.. _YouTube: https://youtube.com

.. _Kick: https://kick.com

.. _Facebook: https://facebook.com

.. _TestFlight: https://testflight.apple.com/join/PDpxEaGh

.. _MobsSettingsUrl.swift: https://github.com/eerimoq/mobs/blob/main/Mobs/MobsSettingsUrl.swift

.. _Settings.swift: https://github.com/eerimoq/mobs/blob/main/Mobs/Settings.swift
