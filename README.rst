MOBS
====

An iOS app for IRL streaming. Mainly targetting `Twitch`_.

.. image:: https://github.com/eerimoq/mobs/raw/main/Docs/main.jpg

Discord: https://discord.gg/kRCXKuRu

Github: https://github.com/eerimoq/mobs

This project is **not** part of `OBS`_. It's just the name that is
inspired by it.

ToDo
====

- Clock hours with two digits.

- Emoji chat.

- Actually change scene.

- Make UI update after buttons reordering and enable/disable.

- Integrate SRT stack.

- Implement SRTLA.

- Selector in image widget.

- Widget button selector.
  
Ideas/plan
==========

- Pause and scroll chat.

- Buffering for short disconnections. Show as picture in picture or
  other layout once reconnected. Possible a record button.

- Geolocation (with map?).

- Play music and short sound samples.

- Record to disk.

- Lookup Twitch channel id from channel name.
  
- `SRTLA`_.

- AV1 codec (to complement H264).

- LIDAR, altitude.

- Subscription and donation notifications. Both visually and with
  sound.

Testing with local streaming server
===================================

#. Start streaming server. You must have `go`_ installed.

   .. code-block::

      $ (cd livego && go run . --level debug)

#. Create the application instance in the server (hard coded to 1234):

   .. code-block::

      $ wget 'http://localhost:8090/control/get?room=movie'

#. Start streaming with iOS app. Build and run the iOS application in
   xcode.

#. Watch stream in VLC:

   .. code-block::

      $ vlc rtmp://localhost:1935/live/movie

Resources
=========

- https://github.com/gwuhaolin/livego

  Streaming server for testing.

- https://twitchapps.com/tmi/

  Create Twitch (chat) token.

.. _OBS: https://obsproject.com

.. _go: https://go.dev

.. _SRTLA: https://github.com/BELABOX/srtla

.. _Twitch: https://twitch.tv
