MOBS
====

An iOS app for IRL streaming. Mainly targetting `Twitch`_, but can
stream to `YouTube`_, `Kick`_, and `OBS Studio`_ as well (and probably more).

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

- Twitch integration.

  - Number of viewers.

  - Chat.

- YouTube integration.

  - None.

- Kick integration.

  - Chat.

- Basic scenes.

- Main or front camera.

- Zoom.

- Connection status.

- Video effects.

  - Grayscale.

  - Movie.

  - Seipa.

- Mute audio.

- Torch.

- Configure resolution, FPS, codec and bitrate.

- Landscape stream only.

ToDo
====

- Fix crashes. =)

- Sometimes video hangs. Often when app is put into background. Or
  when changing settings.

Ideas/plan
==========

- Adaptive bitrate, but based on what?

- Video effects:

  - Sparks.

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

- Buffering for short disconnections. Show as picture in picture or
  other layout once reconnected. Possibly a record button.

- Play music and short sound samples.

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

.. _TestFlight: https://testflight.apple.com/join/PDpxEaGh
