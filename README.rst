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

- Make SRT work. Unknown why is fails to send video so often. Audio
  seems to work?

- Sometimes the screen freezes after settings updates. Unknown why.

- Receonnect, or change button text from "Stop" to "Go live".

Ideas/plan
==========

- Big F on screen when disconnected.

- Implement `SRTLA`_.

- Reconnect immediately when connected to a network.

- Network status (WiFi, cellular, ...).

- Audio level indicator.

- Audio only when bad connection.

- Adaptive bitrate, but based on what?

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

- https://github.com/matthew1000/gstreamer-cheat-sheet/blob/master/srt.md

  GStreamer SRT stuff.

SRT debug
=========

Stream from MOBS to OBS fails most of the time. Audio is fine
though. Just video is bad somehow.

Stream from MOBS to GStreamer works 100% of the time.

.. code-block::

   gst-launch-1.0 -v srtsrc uri="srt://:5000?mode=listener" ! decodebin ! autovideosink

Stream from GStreamer to OBS works 100% of the time:

.. code-block::

   gst-launch-1.0 -v videotestsrc ! video/x-raw, height=720, width=1280 ! videoconvert ! x264enc tune=zerolatency ! video/x-h264, profile=high ! mpegtsmux ! srtsink uri=srt://192.168.50.72:5000

Similar apps
============

- https://irlpro.app/

- Twitch app.

.. _OBS: https://obsproject.com

.. _go: https://go.dev

.. _SRTLA: https://github.com/BELABOX/srtla

.. _Twitch: https://twitch.tv

.. _App Store: https://www.apple.com/app-store/
