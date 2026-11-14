# Privacy Policy

Moblin — last updated 31 August 2026.

Moblin is a free and open source IRL live streaming app for iOS, iPadOS and watchOS, developed
by Erik Moqvist ("we", "us"). This Privacy Policy explains what information Moblin (the "app")
accesses, collects, stores, uses and shares, and what choices you have over that information.

Moblin has no backend servers of its own. All settings and all data described below are stored
on your device, and the app communicates only with the streaming platforms and services that
you yourself configure in the app.

## 1. YouTube API Services and the YouTube Terms of Service

Moblin uses **YouTube API Services**. Moblin is an API Client of the YouTube API Services and
uses them to let you manage and go live with your own YouTube live streams from within the app.

**By using Moblin, you are agreeing to be bound by the YouTube Terms of Service, available at
[https://www.youtube.com/t/terms](https://www.youtube.com/t/terms).**

Google's use of information received from the YouTube API Services, and any information Google
collects when you sign in with your Google Account, is governed by the **Google Privacy
Policy**, available at
[http://www.google.com/policies/privacy](http://www.google.com/policies/privacy).

## 2. Information Moblin accesses, collects and stores

### 2.1 YouTube (API Data)

When you choose to connect a YouTube account, Moblin asks you to sign in with your Google
Account through Google's own sign-in page (OAuth 2.0). Moblin never sees or stores your Google
password. Moblin requests the `https://www.googleapis.com/auth/youtube` scope, and uses it to
call the YouTube Data API v3 at `youtube.googleapis.com`. Through those calls Moblin accesses:

| Data | Why it is accessed |
| --- | --- |
| OAuth 2.0 access token and refresh token for your Google Account | To authorize the API calls listed below on your behalf |
| Your channel (`channels.list`, `mine=true`, `snippet`): channel name, channel id and channel thumbnail | To show which account you are signed in as |
| Your live broadcasts (`liveBroadcasts.list/insert/delete/bind/transition`): titles, scheduled and actual start times, privacy status, broadcast ids and status | To list, create, schedule, start, stop and delete your live streams from the app |
| Your live streams (`liveStreams.list`, `mine=true`): stream keys, ingestion (RTMP) addresses and stream health status | To send your video to the correct YouTube ingestion endpoint and show stream health |
| Video details (`videos.list`, `liveStreamingDetails`): concurrent viewer count and live chat identifiers | To show viewer count and to read the live chat of your stream |
| Public live chat messages for the stream you are watching or broadcasting: message text, author display name, author badges (moderator, member, owner), Super Chat / Super Sticker amounts, membership and gifted-membership events | To display chat in the app, on the Apple Watch, in stream overlays and in optional chat features such as alerts, text-to-speech and chat bot commands |

Moblin does **not** access your Google contacts, email, Drive, watch history, subscriptions or
any Google data outside of the YouTube live streaming data listed above.

### 2.2 Other streaming platforms

If you configure them, Moblin connects in a comparable way to Twitch, Kick, Facebook, OBS
Studio and other services you enter yourself. For those services Moblin stores the credentials,
tokens, stream keys, channel names and URLs that you provide, and reads chat, viewer counts and
stream status from them. Your use of those services is governed by their own terms and privacy
policies.

### 2.3 Information created on your device

Moblin records or processes, entirely on your device, the video, audio, screen recordings,
photos, chat history, log files, and — only if you enable the relevant features — location
data, workout and heart rate data from a connected watch, and data from connected accessories
(cameras, DJI devices, GoPro, printers, Tesla vehicles).

### 2.4 Information we do not collect

Moblin contains no analytics, no advertising, no tracking SDKs and no crash-reporting service.
We do not receive your personal information, your API Data, your streams, your chat or your
usage of the app, because none of it is sent to us.

## 3. Information stored on, accessed from or collected from your device

Moblin stores, accesses and collects information directly on your device, as follows:

- **Apple Keychain.** Your YouTube/Google OAuth access and refresh tokens, and the credentials
  and stream keys of other platforms, are stored encrypted in the iOS Keychain of your device.
- **App settings file.** All other settings (scenes, widgets, channel handles, chat bot
  configuration, connected devices) are stored in a JSON settings file and in standard app
  preferences inside the app's own sandbox on your device.
- **Recordings and log files.** Recordings, replays, snapshots and diagnostic logs are written
  to the app's storage on your device until you delete them or delete the app.
- **Cookies and similar technology.** Signing in to YouTube happens in a system-provided secure
  web view, and Google and YouTube may place, access or recognize cookies and similar
  identifiers in that web view on your device as part of signing in. Moblin also sends a
  YouTube consent cookie value when it looks up the public video id of a channel handle, and
  browser-source widgets you add yourself run in a web view that can store cookies and local
  storage for the pages you load. Moblin itself does not use cookies for advertising, analytics
  or cross-site tracking.

## 4. How the information is used, processed and shared

Moblin uses the information described above only to provide the features you activate:
authenticating you with the platform, listing and managing your live streams, sending your
video and audio to the ingestion endpoint you selected, and displaying chat, viewer counts and
stream status.

All processing happens locally on your device. We do not sell your information, we do not use
it for advertising or profiling, and we do not use it to build user profiles.

### 4.1 Internal parties

Moblin is developed by an individual developer with no employees, servers or internal systems
that receive your data. No information is shared internally, because no information reaches us.

### 4.2 External parties

Information leaves your device only to the services you have configured, and only for as long
as you use them:

- **Google / YouTube** — API requests and your video and audio stream, when you sign in and go
  live on YouTube. Governed by the
  [Google Privacy Policy](http://www.google.com/policies/privacy).
- **Other streaming platforms and servers you configure** — Twitch, Kick, Facebook, OBS Studio,
  your own RTMP/SRT/RIST/WHIP servers, and remote-control or relay servers whose addresses you
  enter.
- **Optional integrations, only if you enable them and provide your own credentials** — for
  example OpenAI (chat messages sent to generate chat bot replies), TTS Monster (chat text sent
  to generate speech), Discord (recordings and clips uploaded to a webhook you configure),
  emote providers such as BTTV, FFZ and 7TV, map and location services, and other third-party
  accessories and services listed in the app's settings. Each of these is governed by that
  provider's own privacy policy.

We may disclose information if required to do so by law, but in practice we hold no user
information that could be disclosed.

## 5. Data retention, deletion and revoking access

### 5.1 Deleting stored data

Authorized data obtained from the YouTube API Services is stored on your device only for as
long as it is needed, and API responses (broadcasts, streams, chat, viewer counts) are kept in
memory only while the app is running. To delete the stored data:

- **To delete your YouTube tokens:** open Settings → Streams → (your stream) → YouTube in
  Moblin and tap **Logout**. This immediately deletes the access and refresh tokens from the
  Keychain of your device. Deleting the stream itself deletes them as well.
- **To delete everything else:** use Settings → Recordings to delete recordings, clear the log
  from the log view in the app's settings, and delete individual streams, scenes and widgets in
  the app's settings.
- **To delete all app data at once:** delete Moblin from your device. iOS removes the app's
  sandbox, its settings file, recordings, logs and its Keychain items.

When the retention period for a given type of data expires, or when you perform any of the
actions above, the data is deleted or destroyed.

### 5.2 Revoking Moblin's access to your Google data

You can revoke Moblin's access to your Google Account data at any time from the Google security
settings page:

[https://myaccount.google.com/connections?filters=3,4&hl=en](https://myaccount.google.com/connections?filters=3,4&hl=en)

Select Moblin in the list of third-party apps and services and remove its access. After
revoking access, any token still stored on your device stops working; use the **Logout** button
described above to delete it from your device as well.

## 6. Security

Tokens and credentials are stored in the Apple Keychain, which is encrypted by iOS.
Communication with Google and YouTube uses HTTPS, and communication with other services uses
the encrypted transport those services provide (for example RTMPS, SRT with encryption, or
HTTPS). No security measure is perfect, but because your data stays on your device, there is no
Moblin server that could be breached.

## 7. Children

Moblin is not directed at children under the age of 13, and we do not knowingly collect
information from children.

## 8. Changes to this Privacy Policy

We may update this Privacy Policy from time to time. The date at the top of this page shows
when it was last changed. Continued use of Moblin after a change means you accept the updated
policy.

## 9. Contact

If you have questions about this Privacy Policy, about the data Moblin accesses, or if you want
help deleting your data, contact us:

- Email: [erik.moqvist@gmail.com](mailto:erik.moqvist@gmail.com)
- Discord: [https://discord.gg/kh3KMng4JV](https://discord.gg/kh3KMng4JV)
- GitHub: [https://github.com/eerimoq/moblin/issues](https://github.com/eerimoq/moblin/issues)

Data controller: Erik Moqvist, Sweden.
