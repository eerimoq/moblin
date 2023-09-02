MOBS
====

An iOS app for IRL streaming.

.. image:: https://github.com/eerimoq/mobs/raw/main/docs/main.jpg

Discord: https://discord.gg/kRCXKuRu

This project is **not** part of `OBS`_. It's just the name that is
inspired by it.

Features
========

- Scenes

- Twitch chat and viewer count

- Movie and grayscale video effects

- RTMP

- iPhone thermal state information
  
Ideas/plan
==========

- Buffering for short disconnections. Show as picture in picture or
  other layout once reconnected. Possible a record button.

- Subscription and donation notifications. Both visually and with
  sound.

- Geolocation.

- Play music and short sound samples.

- Streamlabs integration.

- Record to disk.

- LIDAR, altitude.

- AV1 codec (to complement H264).

- `SRTLA`_.
  
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

.. _go: https://go.dev

.. _SRTLA: https://github.com/BELABOX/srtla
