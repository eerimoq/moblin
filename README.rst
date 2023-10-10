MOBS
====

An iOS app for IRL streaming. Mainly targetting `Twitch`_, but can
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

- Configure resolution, FPS, codec and bitrate.

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

- Adaptive bitrate, but based on what?

- Interactive local browser(s).

- Tap to focus.

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
