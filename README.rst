MOBS
====

A free iOS app for IRL streaming. Mainly targetting `Twitch`_, but can
stream to any RTMP, RTMPS, SRT or SRTLA endpoint.

Not yet in App Store, but on `TestFlight`_!

.. image:: https://github.com/eerimoq/mobs/raw/main/Docs/main.jpg

Discord: https://discord.gg/nt3UwHqbMM

Github: https://github.com/eerimoq/mobs

TestFlight: https://testflight.apple.com/join/PDpxEaGh

This project is **not** part of `OBS`_. It's just the name that is
inspired by it.

Features
========

- Stream using RTMP, RTMPS, SRT or SRTLA.

- H.264/AVC and H.265/HEVC video codecs.

- Twitch integration.

  - Number of viewers.

  - Chat.

- YouTube integration.

  - None.

- Kick integration.

  - Chat.

- Configure resolution, FPS, codec and bitrate.

- Landscape stream only.

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

ToDo
====

- Move SRT to non-main dispatch queue. Video interruptions now when
  zooming slowly, and probably same for other UI actions as well.

- Fix crashes. =)

- Sometimes video hangs. Often when app is put into background.

- Blinking icons instead of color cyan when trying to connect.

Ideas/plan
==========

- Adaptive bitrate, but based on what?

- Lookup Twitch channel id from channel name. Possibly login to
  Twitch.

- Big F on screen when disconnected.

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

Resources
=========

- https://pad.riseup.net/p/IRLstreamingforFreeorCheap-keep

  How to IRL stream for free or cheap.

- https://twitchapps.com/tmi/

  Create Twitch (chat) token.

- https://irl.run

  IRL Toolkit.

- https://belabox.net/

  BELABOX

- https://haivision.github.io/srt-rfc/draft-sharabayko-srt.html

  SRT spec

Twitch user to id
=================

Run on own server. Or possibly make the user login to Twitch with own
account.

.. code-block::

   SECRET=<my-app-secret>
   TOKEN=$(curl -s -X POST 'https://id.twitch.tv/oauth2/token' \
       -H 'Content-Type: application/x-www-form-urlencoded' \
       -d "client_id=9y23ws4svxsu2tm17ksvtp6ze3zytl&client_secret=$SECRET&grant_type=client_credentials" | jq -r '.access_token')
   curl -s -X GET 'https://api.twitch.tv/helix/users?login=eerimoq' \
       -H "Authorization: Bearer $TOKEN" \
       -H 'Client-Id: 9y23ws4svxsu2tm17ksvtp6ze3zytl' | jq -r '.data[0].id'

Similar software
================

- https://irlpro.app/

- Twitch app.

- https://github.com/pedroSG94/RootEncoder-iOS

.. _OBS: https://obsproject.com

.. _go: https://go.dev

.. _SRTLA: https://github.com/BELABOX/srtla

.. _Twitch: https://twitch.tv

.. _TestFlight: https://testflight.apple.com/join/PDpxEaGh
