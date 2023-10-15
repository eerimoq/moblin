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

  - Browser widget (not yet fully functional). Show a web page on
    stream.

- Back or front camera.

  - Front camera mirrored on screen for natural experience.

- Back, front or bottom mic.

- Mute audio.

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

- Torch.

- Configure resolution, FPS, codec, bitrate and more.

- Deep link settings (mobs://).

- Landscape stream only.

ToDo
====

- Changing stream from SRT to SRT always hangs video.

- Improve the browser widget.

- Fix crashes. =)

- Sometimes video hangs when changing settings or when enter/exit
  background mode. Looks like there is two sessions if changing stream
  from RTMP to SRT. Should only be one.

- Overlays are mirrored locally when using front camera. Ok, or needs
  change?

Ideas/plan
==========

- Filter for button icons.

- A handle to show that items in some lists are draggable.

- Change app icon on home screen when changing in app.

- Remove zeros from bitrate preset config.

- Toggles to enable/disable "Go live" and "Stop" confirmations. Per
  stream?

- Automatically go live when starting app, if configured for selected
  stream setting.

- MOBS icon in dynamic island has a square around it. Should be
  transparent.

- Use external mic.

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

- Timestamp overlay. Possibly with a format string, and background and
  foreground colors.

- Local horizon overlay.

- Local grid overlay? What is this used for?

- Safe margins local overlay? What is this used for?

- Settings on half landscape screen so video can be seen when changing
  settings. Minimize button? Transparent?

- Investigate video stabilization API.

- Show web page on stream and/or locally. Audio kinda important.

- Multiple Ethernet connections simultaneously?

- Snapshot button.

- Lookup Twitch channel id from channel name. Possibly login to
  Twitch.

- App running in background? What is possible? Video can not run in
  background. Audio can most likely.

- Audio only when bad connection.

- Notifications. Both visually and with sound. Sound most important
  probably.

- Emoji chat.

- Show two cameras at the same time.

- Bigger chat text? Bigger text in general?

- Preview buttons.

- Pause and scroll chat.

- Play music and short sound samples.

- Stream mobile games.

- Geolocation (with map?).

- Record to disk.

- Graphical scene setup? However, overlays will probably be added
  server side by most streamers, so not that important to change.

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
