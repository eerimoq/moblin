MOBS
====

An iOS app for IRL streaming. Mainly targetting `Twitch`_, but can
stream to any RTMP endpoint.

Not yet in `App Store`_, but hopefully soonish!

.. image:: https://github.com/eerimoq/mobs/raw/main/Docs/main.jpg

Discord: https://discord.gg/nt3UwHqbMM

Github: https://github.com/eerimoq/mobs

This project is **not** part of `OBS`_. It's just the name that is
inspired by it.

ToDo
====

- Make SRT work.

- Test with cellular connection, not only WiFi.
  
Ideas/plan
==========

- Implement `SRTLA`_.

- Reconnect immediately when connected to a network.

- Network status (WiFi, cellular, ...).
  
- Audio level indicator.

- Audio only when bad connection.

- Notifications. Both visually and with sound. Sound most improtant
  probably.

- Emoji chat.

- Preview buttons.

- Pause and scroll chat.

- Buffering for short disconnections. Show as picture in picture or
  other layout once reconnected. Possible a record button.

- Play music and short sound samples.

- Geolocation (with map?).

- Record to disk.

- Graphical scene setup? However, overlays will probably be added
  server side by most streamers, so not that important to change.

- Lookup Twitch channel id from channel name. Possibly login to
  Twitch.

- LIDAR, altitude.

- WebRTC.

Testing with local streaming server
===================================

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

- https://twitchapps.com/tmi/

  Create Twitch (chat) token.

- https://irl.run

  IRL Toolkit.

Similar apps
============

- https://irlpro.app/

- Twitch app.

.. _OBS: https://obsproject.com

.. _go: https://go.dev

.. _SRTLA: https://github.com/BELABOX/srtla

.. _Twitch: https://twitch.tv

.. _App Store: https://www.apple.com/app-store/
