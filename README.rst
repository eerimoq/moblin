MOBS
====

An iOS app for IRL streaming.

🚧 🚧 🚧 UNDER CONSTRUCTION 🚧 🚧 🚧

This project is **not** part of `OBS`_. It's just the name that is
inspired by it.

.. image:: https://github.com/eerimoq/mobs/raw/main/docs/main.jpg

Testing with local streaming server
===================================

#. Start streaming server.

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

Ideas
=====

- Show latency, bitrate, resolution, protocol, ...

- Built-in support for commonly used streaming platforms (Twitch,
  Youtube, etc.).

  - Show number of viewers, chat, title, uptime, etc.

- LIDAR, altitude, geolocation.

- Picture in picture.

- Record to disk in different resolution than stream.

- Energy efficient.

- Streamlabs integration.

- Subscription and donation notifications. Both visually and with
  sound.

- Buffering for short disconnections. Show as picture in picture or
  other layout once reconnected. Possible a record button.

- Play music and short sound samples.

- Filters.

- Two-way video and/or audio.

Resources
=========

- https://github.com/cocoatype/twitch-chat

  Receive Twitch chat messages in Swift.

- https://github.com/gwuhaolin/livego

  Streaming server for testing.

- https://github.com/shogo4405/HaishinKit.swift

  Camera capture and RTMP streaming in Swift.

- https://twitchapps.com/tmi/

  Create Twitch (chat) token.

- https://github.com/loopy750/SRT-Stats-Monitor

  Stream switcher on low bitrate.

Twitch PubSub over websocket
============================

URL: wss://pubsub-edge.twitch.tv/v1

Viewer count. Set channel id (123668195) in settings.

.. code-block::

   > {"type":"LISTEN","data":{"topics":["video-playback-by-id.123668195"]}}
   < {"type":"MESSAGE","data":{"topic":"video-playback-by-id.123668195","message":"{\"type\":\"viewcount\",\"server_time\":1692772100.706721,\"viewers\":63}"}}

   > {"type":"LISTEN","data":{"topics":["video-playback-by-id.159498717"]}}

   /

.. _OBS: https://obsproject.com
   
