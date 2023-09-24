MOBS
====

A free iOS app for IRL streaming. Mainly targetting `Twitch`_, but can
stream to any RTMP, RTMPS or SRT endpoint.

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

- Twitch.

  - Number of viewers.

  - Chat.

- Kick.

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

- H.264/AVC video codec.

ToDo
====

- Find out why H.265 does not work.

- Fix crashes. =)

- Sometimes video hangs. Often when app is put into background.

- Blinking icons instead of color cyan when trying to connect.

Ideas/plan
==========

- Adaptive bitrate, but based on what?

- Lookup Twitch channel id from channel name. Possibly login to
  Twitch.

- Big F on screen when disconnected.

- App running in background? What is possible?

- Reconnect immediately when connected to a network.

- Audio only when bad connection.

- Notifications. Both visually and with sound. Sound most improtant
  probably.

- Emoji chat.

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

Testing with local RTMP streaming server
========================================

#. Start streaming server. You must have `go`_ installed.

   .. code-block::

      $ (cd livego && go run . --level debug)

#. Create the application instance in the server (hard coded to 1234):

   .. code-block::

      $ wget 'http://localhost:8090/control/get?room=movie'

#. Start streaming with Dev stream.

#. Watch stream in VLC:

   .. code-block::

      $ vlc rtmp://localhost:1935/live/movie

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
