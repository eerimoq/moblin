import SwiftUI

struct Version {
    var version: String
    var changes: [String]
}

// swiftlint:disable line_length
private let versions = [
    Version(version: "0.112.0", changes: [
        "• Shorter disconnected and failed to connect error messages.",
        "• Create stream wizard continued.",
        "• Increased default bitrate from 3 Mbps to 5 Mbps.",
        "• Only show SRT(LA) settings when SRT(LA) is configured in URL.",
        "• Message in OBS remote control toasts.",
        "• Add failure toast if start/stop OBS stream fails.",
        "• Show bad URL error message after input field instead of as a toast.",
    ]),
    Version(version: "0.111.0", changes: [
        "• Rework connection toasts.",
        "  • Show FFFFF if disconnected.",
        "  • Show Failed to connect if no connection could be established.",
        "  • Increase initial reconnect timer to 7 seconds (from 5). It gets higher over time, up to 60 seconds.",
        "• Average and highest bitrate in stream summary statistics.",
    ]),
    Version(version: "0.110.0",
            changes: [
                "• Confirm dialog when pressing OBS start/stop stream button.",
                "• Move Local overlays, Tap screen to focus, Battery percentage and Quick buttons to Display settings.",
                "• Move Back camera, Front camera, Zoom, Bitrate presets and Video stabilization to Camera settings.",
                "• Only show bitrate and uptime local overlays in top right when live.",
                "• Global buttons. Only widget buttons are per scene now. The rest are always visible (if enabled in Settings -> Display -> Quick buttons).",
                "  • This makes new buttons appear automatically when upgrading.",
                "• Highest thermal state in streaming history.",
                "• Lowest battery percentage in streaming history.",
                "• Create stream wizard continued.",
                "• Record UI started. Behind experimental toggle. Does not save audio and video to file yet.",
                "• Version history (changelog) in Settings -> About -> Version history.",
                "• Rename Quick buttons to Buttons.",
            ]),
    Version(version: "0.109.0",
            changes: [
                "• B-frames toggle.",
                "• Fix total bytes for RTMP streams in streaming history.",
            ]),
    Version(version: "0.108.0",
            changes: [
                "• Create stream wizard continued.",
                "• Fixed swapped H.264 and H.265 in local overlay.",
                "• Streaming history with some basic information.",
                "• Fix \"dropped frames\" when streaming RTMP(S) directly to Twitch, Kick and YouTube.",
                "  • Disabling frame reordering (aka B-frames) makes it work. Has been broken since 0.5.0 😄",
            ]),
    Version(version: "0.107.0",
            changes: [
                "• Unfinished \"create stream wizard\" behind experimental toggle.",
                "  • Enable wizard with Settings -> Debug -> Create stream wizard.",
                "• Show announcements when using Twitch chat.",
                "• 128 Kpbs audio bitrate by default.",
                "• Slightly more compact stream info in UI.",
                "• Slider to configure audio bitrate.",
            ]),
    Version(version: "0.106.0",
            changes: [
                "• iOS 16.4",
                "• Support for any number of Ethernet connections in SRTLA (not yet confirmed that it works).",
                "  • Still max one WiFi and one Cellular.",
            ]),
    Version(version: "0.105.0",
            changes: [
                "• Require iOS 17.2 or higher.",
                "  • The plan is to support iOS 16.4 as well.",
                "• Find external cameras.",
                "  • I only get it working on Mac 😦",
            ]),
    Version(version: "0.104.0",
            changes: [
                "• Fix camera selection when running the iOS app on macOS.",
            ]),
    Version(version: "0.102.0",
            changes: [
                "• Quick button settings.",
                "  • Toggle to enable and disable scroll.",
                "  • Toggle to show button names.",
                "  • Toggle to show one or two columns.",
                "    • The buttons are slightly larger when using one column.",
                "• More translations updates.",
                "• Toggles to enable/disable BTTV, FFZ and 7TV emotes.",
                "  • Settings -> Streams -> My Stream -> Chat",
            ]),
    Version(version: "0.101.0",
            changes: [
                "• Allow audio bitrate up to 320 kbps. Device dependent what the actual limit is.",
                "  • Will show your configured bitrate in UI. Might be lower in audio encoder (probably 192 kbps).",
            ]),
    Version(version: "0.100.0",
            changes: [
                "• Make audio bitrate configurable. 32 • 192 kbps (AAC). 64 kbps by default. Should probably be increased later on.",
                "  • I have not tested if the quality is better with higher bitrate. But it should be 🙂",
            ]),
    Version(version: "0.99.1",
            changes: [
                "• Fix screen video sometimes mirrored.",
            ]),
    Version(version: "0.99.0",
            changes: [
                "• Support for Twitch chat /me, optionally in username color.",
                "• Fix camera names when running on macOS.",
                "• Google translated strings in some places. To be improved, for sure! 🙂",
            ]),
    Version(version: "0.98.0",
            changes: [
                "• Spanish, German and French translation updated.",
                "• Toggles to enable/disable Twitch, Kick, YouTube, AfreecaTV and OBS remote control.",
            ]),
    Version(version: "0.97.0",
            changes: [
                "• Default zoom presets based on iPhone model.",
                "• Allow settings OBS websocket URL to empty string.",
            ]),
    Version(version: "0.96.1",
            changes: [
                "• Fix OBS websocket error \"The resource could not be loaded because the App Transport Security policy requires the use of a secure connection\" by allowing non-secure connections.",
            ]),
    Version(version: "0.96.0",
            changes: [
                "• Show OBS WebSocket password as stars.",
                "• Rename back cameras to make them easier to understand.",
                "• Fewer bitrate presets by default (1, 3, 5 and 7 Mbps).",
                "• Updated German and French translations.",
            ]),
    Version(version: "0.95.2",
            changes: [
                "• Show OBS scenes in the same order as in OBS.",
            ]),
    Version(version: "0.95.1",
            changes: [
                "• Fix OBS websocket crash when entering an invalid URL.",
            ]),
    Version(
        version: "0.95.0",
        changes: [
            "• Start/stop OBS stream button (using OBS websocket/remote control).",
            "• Change default stream settings to 1080p, H.265 and srt://my_public_ip:4000. Rename default stream from Twitch to Main.",
            "• Show toast explaining that the stream URL has to be configured before going live.",
            "• Show OBS websocket connection error message in UI (top left).",
        ]
    ),
    Version(
        version: "0.94.0",
        changes: [
            "• OBS Websocket settings in deep link.",
            "  • See https://github.com/eerimoq/moblin#import-settings-using-moblin-custom-url for details.",
            "• Optionally show current OBS scene, streaming state and recording state in top left of UI.",
            "• \"All icons\" subscription (monthly and yearly).",
        ]
    ),
    Version(
        version: "0.93.0",
        changes: [
            "• More icons in store.",
            "• Translations update.",
            "• Black screen button.",
            "• Use new screen rendering again (as it saves energy), at least for now.",
            "• Fix out of sync mirroring when swapping camera.",
            "• Change OBS scene on server.",
        ]
    ),
    Version(
        version: "0.92.0",
        changes: [
            "• Allow non-lowercased scheme and spaces in stream URL.",
            "  • Automatically convert scheme to lower case and remove spaces.",
            "• Always show the whole URL. Use multiple lines if needed.",
            "• Move back to using metal screen rendering to find out if it fixes screen lag problem.",
            "  • It uses more CPU, so will make phone warmer. Hopefully ok.",
        ]
    ),
    Version(
        version: "0.91.0",
        changes: [
            "• Updated translations.",
            "• Updated usage strings for App Store.",
        ]
    ),
    Version(
        version: "0.90.0",
        changes: [
            "• Camera and microphone usage descriptions (requested by App Store review).",
        ]
    ),
    Version(
        version: "0.89.0",
        changes: [
            "• Reorder scenes to your liking.",
            "• Duplicate scene button when swiping left.",
            "• Duplicate stream button when swiping left.",
            "• Korean translation started.",
            "• Fix empty string translation in German.",
        ]
    ),
    Version(
        version: "0.88.0",
        changes: [
            "• Fix wrong zoom factor limits on telephoto camera.",
            "• Updated French, German and Polish translations.",
        ]
    ),
    Version(
        version: "0.87.0",
        changes: [
            "• German translation.",
            "• More icons.",
        ]
    ),
    Version(
        version: "0.86.0",
        changes: [
            "• Fix upside-down video when starting app in landscape right.",
        ]
    ),
    Version(version: "0.85.0",
            changes: [
                "• Zoom speed setting.",
                "• Add dual wide camera to list of back cameras.",
                "• Optionally show selected (back) camera in top left of UI.",
                "• Only show zoom presets that are relevant for current lens and camera.",
                "• Fix zoom limits for all lenses.",
                "  • Known bug: Telephoto camera is hard coded to 5x. So only works correctly for 15 Pro Max.",
                "• Initial support for AfreecaTV chat.",
                "• Remove buggy bloom filter. It didn't work and I'm sure nobody uses it, right? 🙂",
                "• Polish, Chinese (Simplified) and French translations.",
                "• Try to fix occasionally lagging screen (by always displaying frames immediately).",
            ]),
    Version(version: "0.84.0",
            changes: [
                "• Debug log number of audio channels and samples every 10 seconds.",
                "• Refactor SRT(LA) remote connection handler. Mainly affects reconnect logic.",
                "• Initial support for Spanish and Swedish. Not finalized, so not all strings are translated.",
                "  • Feel free to help out translating to your language.",
            ]),
    Version(version: "0.82.0",
            changes: [
                "• Røde audio level debug.",
                "  • Enable Settings -> Debug -> Audio -> Røde audio level and audio level should show in top right of UI.",
                "  • When enabled, audio level is based on first channel. Other channels are ignored.",
            ]),
    Version(version: "0.81.0",
            changes: [
                "• More optimizations for less power usage.",
                "  • Quite big changes. Might break something.",
                "• Fix muted not showing in UI.",
                "• Reorder settings.",
            ]),
    Version(version: "0.80.0",
            changes: [
                "• Key frame interval settings. 2 by default (as it was before).",
                "  • Settings -> Streams -> Stream -> Video -> Key frame interval",
                "  • Usually 2 is good. Higher means potentially higher video quality for same bitrate. Lower means faster recovery from frame drops.",
                "• Update chat in UI every 200 ms instead of immediately on every message.",
                "  • Not to flood UI update engine when lots of messages are received.",
                "• Back and front camera selection (triple, dual, ultra wide, wide and telephoto).",
                "  • Zoom works, but factor is a bit off I think.",
                "  • Settings -> Back camera",
                "  • Settings -> Front camera",
            ]),
    Version(version: "0.79.0",
            changes: [
                "• A few optimizations that lowers CPU usage a little.",
                "  • Audio level meter only updates if dB changes more than 5 dB. Maybe lower the threshold a little later on.",
            ]),
    Version(version: "0.78.0",
            changes: [
                "• Automatically navigate back from picker views on selection change.",
                "• Revert always using multi camera capture session as 720p does not work with it.",
            ]),
    Version(version: "0.77.0",
            changes: [
                "• Fix RTMP crash when going live second time.",
            ]),
    Version(version: "0.76.0",
            changes: [
                "• Replace \"Some settings are disabled when Live\" alert with similar information on first settings page.",
                "• Time widget background.",
                "• Preparations for Picture in Picture.",
                "  • Reworked scene settings camera selection.",
                "  • Using multi camera capture session instead of single camera capture session. Will hopefully work on phones that do not support multi camera capture.",
                "• Major refactoring in streaming code. Hopefully no functional change.",
            ]),
    Version(version: "0.75.0",
            changes: [
                "• Optionally configure SRT overhead bandwidth. Mostly for testing things in first release.",
                "• Some logging of SRTLA trying to reconnect when it shouldn't.",
                "• A few small optimizations to use less energy.",
                "  • Saves a few percent CPU when the scene has no widgets.",
            ]),
    Version(version: "0.74.0",
            changes: [
                "• All haishinkit logging as debug.",
                "• Adaptive bitrate cracking audio after low bitrate fix (hopefully) when streaming to OBS.",
                "  • Bitrate will settle for about 80% of target bitrate. Under investigation.",
                "  • New algorithm will not change resolution to achieve low bitrate, but always set dataRateLimits instead.",
            ]),
    Version(version: "0.73.0",
            changes: [
                "• \"Designed by\" list.",
                "  • Just let me know if you want be added to the list, and I'll consider it 🤔",
                "• Higher allowed exposure duration (integration time).",
                "• Exposure bias debug setting.",
                "• Fix duplicated Kick chat messages.",
                "• Fix video freeze when using RTMP and entering/exiting background.",
                "  • Probably not fully fixed.",
                "• Fix duplicated twitch viewers connection.",
                "• Adjusted adaptive bitrate algorithm.",
                "• Quickly reconnect chat and viewers after entering foreground.",
                "• Selected builtin mic saved.",
                "• Added cinematic image stabilization (in addition to off and standard).",
                "• Replace debug toggle with log level picker and SRT overlay toggle.",
                "  • Save the two settings to disk.",
            ]),
    Version(version: "0.72.0",
            changes: [
                "• Return to previous settings page automatically when done editing text field.",
                "  • For easier settings navigation.",
                "• Save text fields when pressing back, if modified.",
                "  • Less error prone.",
                "• Same close button style in mic and bitrate quick settings as main settings.",
                "• Warning message if chat is hidden (just like for paused).",
                "• Do not change scene when moving widgets.",
                "• Select chat font size with slider.",
            ]),
    Version(version: "0.71.0",
            changes: [
                "• Configurable maximum chat message age in seconds. Disabled by default.",
                "• Kick chat emotes.",
                "• Bigger settings close button \"hit area\"?",
                "• Settings close button alignment.",
            ]),
    Version(version: "0.70.0",
            changes: [
                "• Disable some settings when Live.",
                "  • To not accidentally stop stream.",
                "• Always show layout picker and close button when in settings.",
            ]),
    Version(version: "0.69.0",
            changes: [
                "• Rework settings layout for more feedback when configuring for example chat.",
                "  • Remove stream preview.",
                "  • Show settings on left half, right half or full screen. Stream visible other half.",
                "• Experimental YouTube chat.",
                "  • Requires Google API Key and Video Id as input.",
                "    • See https://console.cloud.google.com/. Create an API Key and enable \"YouTube Data API v3\".",
                "    • See https://www.youtube.com/watch?v=<videoId> for Video Id.",
                "• Goblina icon (future Moblina?)",
            ]),
    Version(version: "0.68.0",
            changes: [
                "• Configurable chat height in percent of screen height (roughly).",
                "• Configurable chat width in percent of screen width (roughly).",
                "• Show \"Chat is paused\" warning message when chat is paused.",
            ]),
    Version(
        version: "0.67.0",
        changes: [
            "• Show chat stats in top left, above viewers.",
            "• Always show entire last chat message.",
            "  • Before this fix last message was often cut in half when screen was full of (long) messages.",
            "• Pause chat button.",
            "  • Can scroll chat while paused.",
            "  • Max 50 messages.",
            "  • Automatically scrolls to bottom when unpaused.",
            "  • Messages after red horizontal line were received while paused.",
            "  • Zoom and scene buttons cannot be pressed with paused chat.",
            "    • Should probably hide them for clarity later on.",
        ]
    ),
    Version(
        version: "0.66.0",
        changes: [
            "• Make control bar wider if Accessibility Button Shapes is enabled.",
            "• Nicer button alignment.",
            "• Optionally use generated square wave as audio source instead of mic for debugging (or really scuffed streams).",
            "• Optional battery percentage.",
            "• Chat statistics redesign with automatic unit (second or minute) and total message count.",
            "• Smoother (moving average) bitrate in UI when using SRT(LA).",
            "  • Mainly because key frames makes jump up and down every second.",
        ]
    ),
    Version(
        version: "0.65.0",
        changes: [
            "• New SRT(LA) adaptive bitrate algorithm, by Rick. Behind toggle.",
            "  • Use SRT delay of 2000 ms, not lower.",
            "  • Lowers resolution to 16x9 when connection is bad.",
            "• Rename deep link URL scheme from mobs:// to moblin://, and fix it!",
            "• Workaround for crash when another app uses audio at the same time.",
            "  • Audio level in UI will say Unknown in this case.",
            "  • If audio freezes, change to another stream setting and back should fix it.",
        ]
    ),
    Version(
        version: "0.64.0",
        changes: [
            "• Rename app to Moblin.",
            "• Use new 7TV emotes API.",
            "  • Old stopped working completely.",
        ]
    ),
    Version(
        version: "0.63.0",
        changes: [
            "• Better support for Larger Text (Display Zoom in iOS settings).",
            "• Better support for Accessibility Button Shapes.",
            "• Slash over hide chat button icon.",
        ]
    ),
    Version(
        version: "0.62.0",
        changes: [
            "• Use external mic if available when starting app.",
            "• Do not close mic selection view when plugging external mic in and out.",
        ]
    ),
    Version(
        version: "0.61.0",
        changes: [
            "• Show long Kick chat messages on same line as username.",
            "• Maximum number of buttons based on text size and zoom.",
            "• Automatically use external mic when plugged in. Fall back to most recently used internal mic when unplugged. (I know, it kinda worked already, but now official.)",
            "  • Builtin front mic always used by default currently.",
            "• Update mic text in top left and mic selection menu on mic change.",
        ]
    ),
    Version(
        version: "0.60.1",
        changes: [
            "• Fix SRT periodically reconnecting bug introduced in 0.60.0.",
        ]
    ),
    Version(
        version: "0.60.0",
        changes: [
            "• Prettier chat message line wrapping.",
            "• Chat message shadow replaced by border.",
            "  • Fairly CPU intensive for busy chats.",
            "• External mic. Only tested with bluetooth headset.",
            "  • No auto selection.",
            "  • Just as before, changing mic interrutps audio and video stream for a short time. To be fixed later.",
            "• Disable purchase button and show spinner until purchase completed.",
            "• SRTLA now automatically adds connections when available. For example when connecting to WiFi.",
            "  • No timers worked since move to non-main thread long time ago. Big problem!",
        ]
    ),
    Version(
        version: "0.59.0",
        changes: [
            "• Fix animated chat emotes.",
            "• Fix chat Twitch chat emotes when long (more than one Unicode point) emojis in message before the Twitch emote.",
            "• Display number of viewers as 12, 118, 1,5K, 10K, 1,2M(?) and similar.",
            "• Queen icon.",
            "• Optional chat message timestamp.",
        ]
    ),
    Version(
        version: "0.58.0",
        changes: [
            "• Re-add full screen settings button of first page.",
            "• New settings maximize and minimize icons.",
            "• Show sensitive text as stars.",
            "• Fix chat sometimes showing as disconnected when connected.",
            "• Improved input validation for twitch chat emotes.",
            "• Get In-App Purchases from App Store (only \"King\" icon).",
            "  • Hopefully this does not impact TestFlight negatively.",
            "  • All icons are free in TestFlight.",
        ]
    ),
    Version(
        version: "0.57.0",
        changes: [
            "• Big SRT packet toggle. Mainly for debugging.",
            "  • Big packets means 7 MPEG-TS packets per SRT packet, 6 otherwise.",
            "• Animated emotes off by default as they are fairly CPU intensive.",
            "• Fixed text editing flickering and copy-paste bug.",
            "  • Now Enter must be pressed to submit text field changes.",
            "  • Had to remove button for full screen settings. Can hopefully re-add it later.",
        ]
    ),
    Version(
        version: "0.56.0",
        changes: [
            "• Button to toggle hide/show chat.",
            "• Slightly better logging and error messages.",
            "• Fix hang when changing stream quickly.",
            "• Remove lots of settings migrations (should not affect users).",
            "• Make paste in URL text field work again. (Or at least better, still not perfect)",
        ]
    ),
    Version(
        version: "0.55.0",
        changes: [
            "• Fix URL cursor jumping around bug.",
            "• Try to fetch emotes again after 30+ seconds on failure.",
            "• Slight performance improvements.",
            "• Bump SRT library to version 1.5.3.",
        ]
    ),
    Version(
        version: "0.54.0",
        changes: [
            "• Emotes are always cached locally for fewer network requests and faster loading.",
            "• Global emotes in Kick chat.",
            "• Redesign chat settings.",
            "• Workaround to make https://github.com/irlserver/irl-srt-server work.",
            "• Show toast if emotes could not be fetched.",
            "• Red chat icon if not connected or emotes failed to load.",
        ]
    ),
    Version(
        version: "0.53.0",
        changes: [
            "• BTTV, FFZ and 7TV emotes. Only for Twitch chat. Kick chat later on.",
            "  • Only cached when animated. To be improved.",
            "  • Optionally animated.",
            "    • Settings -> Local overlays -> Chat -> Animated emotes",
            "  • Sometimes 7TV emotes are not received from server. Unknown why.",
            "• Fix \"Muted\" font color in light mode.",
            "• Separate bold toggles for username and message.",
        ]
    ),
    Version(
        version: "0.52.0",
        changes: [
            "• Twitch emotes in chat.",
            "  • Messages with emotes that are longer than the screen is wide are weirdly formatted.",
        ]
    ),
    Version(
        version: "0.51.0",
        changes: [
            "• Display chat username in color received from Twitch, if available.",
            "• Manual focus point when phone is rotated 180 degrees now works.",
            "• Remove manual focus point if rotating the phone more than 10 degrees in any direction.",
            "  • Remove auto focus toast.",
            "  • Will be hard to use manual focus when in a moving vehicle.",
            "• Move adaptive bitrate toggle from Video to SRT(LA) page.",
            "• Colorful audio level meter that updates with 5 Hz.",
        ]
    ),
    Version(
        version: "0.50.0",
        changes: [
            "• Configurable chat font size. Increased to 17 (from 13) by default.",
            "  • Settings -> Local overlays -> Chat -> Font size",
            "• Total chat redesign with lots of configuration possibilities. Please let me know if you want the old chat design back.",
            "  • Username and message colors.",
            "  • Optionally bold text.",
            "  • Optional background.",
            "  • Optional text shadow.",
        ]
    ),
    Version(
        version: "0.49.0",
        changes: [
            "• Fix SRT and SRTLA URL parameters bug. Now srt://foo.com:1234?latency=2000 works.",
            "• SRT and SRTLA latency setting in milliseconds in UI. Any latency parameter given in the URL overrides this setting.",
            "  • Settings -> Streams -> Stream -> SRT & SRTLA -> Latency",
            "• Support for both left and right landscape orientation. Video always with gravity down (never upside down).",
            "• Audio level as bar or number. Color thresholds are set to -8 dB (red) and -18 dB (yellow). One bar is -60 dB.",
            "  • Bar colors to be added. Currently icon changes color.",
        ]
    ),
    Version(
        version: "0.48.0",
        changes: [
            "• Fix light mode in settings.",
        ]
    ),
    Version(
        version: "0.47.0",
        changes: [
            "• Change preview to selected scene when in settings.",
            "• Rework settings buttons in top right. Should be easier to press now.",
        ]
    ),
    Version(
        version: "0.46.0",
        changes: [
            "• Various minor UI tweaks.",
            "• Major UI rework. Introducing a split view where settings and video are displayed at the same time. Makes it easier to see setting changes and especially easier scene setup.",
            "  • Video on screen becomes black if quickly opening and closing settings. Unknown why. Just press slower and it seems to work.",
            "  • Previewed scene cannot be changed from settings. Select the scene you want to see before opening settings.",
        ]
    ),
    Version(
        version: "0.45.0",
        changes: [
            "• Button icon filter styling.",
            "• Fix crash when going live with SRT stream URL with query parameter without value, for example srt://foo.com?streamid.",
        ]
    ),
    Version(
        version: "0.44.0",
        changes: [
            "• Swapping between SRT streams works now. Video do not freeze anymore.",
            "• Configure video stabilization as Off or Standard at Settings -> Video stabilization.",
            "• Replace debug log copy and clear text buttons with images. Share link instead of copy to clipboard.",
        ]
    ),
    Version(
        version: "0.43.0",
        changes: [
            "• White battery and thermal level indicators when all good.",
            "• Fix settings page getting stuck in landscape mode. I hope...",
            "• Zoom and scene pickers styling (fix bottom padding).",
            "• Fix invisible button icon picker in light mode.",
        ]
    ),
    Version(
        version: "0.42.0",
        changes: [
            "• Icon (three horizontal lines) on list items that can be moved.",
            "• Input bitrate presets in Mbps instead on bits.",
            "• Make battery indicator border white.",
            "• Button icon selection in filtered grid view.",
            "• Import/export as JSON blob instead of base64 encoded JSON blob.",
            "• Store bitrate preset settings to disk on move, delete and create.",
        ]
    ),
    Version(
        version: "0.41.0",
        changes: [
            "• Time widget, showing local time as HH:MM:SS. For example 14:44:10. Hard coded font and size. To be continued.",
            "• Split local overlays settings page in sections.",
            "• More icons.",
            "• Redesigned battery indicator.",
            "• Optionally set X zoom (rename to default zoom?) when switching to a camera.",
            "• Maximum screen FPS setting.",
            "• Change icon on home screen when changing icon in app.",
            "• Default widget position and size based on widget type.",
            "  • Time widget in top right.",
            "  • Image and browser not covering whole screen.",
        ]
    ),
    Version(
        version: "0.40.0",
        changes: [
            "• Make icon selection survive app restart.",
            "• Show manual focus point as yellow box.",
            "• Show store closed alert when trying to buy icon.",
            "• Always auto focus after camera swap.",
        ]
    ),
    Version(
        version: "0.39.0",
        changes: [
            "• Logging of available mics.",
            "• Create streams using mobs:// custom URL.",
            "  • See https://github.com/eerimoq/mobs/tree/main#import-settings-using-mobs-custom-url for details.",
            "• Icon cosmetics. Can select plain or Halloween icon. Showcase more icons. Selection is currently reset at app start. And btw, I designed them, so they are not that pretty. 🙂",
        ]
    ),
    Version(
        version: "0.38.0",
        changes: [
            "• Configurable bitrate presets.",
        ]
    ),
    Version(
        version: "0.37.0",
        changes: [
            "• Tap screen to focus feature off by default.",
            "• Set focus point to center of screen when returning to auto focus mode.",
        ]
    ),
    Version(
        version: "0.36.0",
        changes: [
            "• Super simple (and probably bad) adaptive bitrate algorithm for SRT(LA). Big work in progress.",
            "  • Enabled with Settings -> Streams -> Stream -> Video -> Adaptive bitrate.",
            "• SRT debug overlay. ",
            "  • Enabled with Settings -> Debug -> Debug.",
            "• Fix tap screen to focus. Double tap to use auto focus again.",
        ]
    ),
    Version(
        version: "0.35.0",
        changes: [
            "• Tap screen to focus.",
            "• Setting to enable/disable \"Tap screen to focus\".",
        ]
    ),
    Version(
        version: "0.34.0",
        changes: [
            "• Current zoom level as local overlay.",
            "• Improved stream URL help. Added Facebook and YouTube examples.",
        ]
    ),
    Version(
        version: "0.33.0",
        changes: [
            "• Pinch to zoom (in addition to zoom presets).",
            "• More intuitive back camera zoom preset levels. That is, level 0.5 is now 0.5x. In previous releases 1.0 was 0.5x, which was not very intuitive.",
        ]
    ),
    Version(
        version: "0.32.0",
        changes: [
            "• Transparent browser widget background.",
            "• Rename microphone to mic.",
            "• Show toast when changing bitrate and mic.",
            "• Apply video mirroring after camera selection for smoother experience.",
            "• Changing mic after app has been in background now works.",
            "• No special audio and video handling when entering and exiting background. Seems to make the app more robust.",
            "• Remove width, height and custom CSS from browser widget settings for now. They were not used anyway.",
            "• Bitrate and mic quick settings displayed on half landscape screen.",
        ]
    ),
    Version(
        version: "0.31.0",
        changes: [
            "• Rename web page to browser (same as OBS).",
            "• Button to select Front, Back or Bottom builtin microphone. You must create the button yourself if you are upgrading from an older MOBS version (Settings -> Scenes -> Buttons and then Settings -> Scenes -> My scene -> Add button). Clean installations will get the button by default.",
            "• Front microphone selected by default.",
            "• Show selected microphone in top-left of UI.",
            "• Browser widget fixes. Still very buggy.",
        ]
    ),
    Version(
        version: "0.30.0",
        changes: [
            "• Dedicated scene camera selection instead of a camera widget. Mostly to simplify implementation. Might be a widget again in the future. Also preparation for picture in picture.",
            "• More widget icons.",
            "• Rename close buttons to cancel in add and create popovers.",
            "• Initial support for web page widgets. Has barely been tested. You probably have to create and configure the widget, and then restart mobs for it to work. They are only updated with 5 Hz, so not very smooth.",
        ]
    ),
    Version(
        version: "0.29.0",
        changes: [
            "• Mirror front camera on iPhone screen. Do not mirror live stream. Unfortunately the mirror effect is applied faster than the camera change, so it looks a bit odd on screen when changing camera. The stream is not affected by this glitch.",
            "• Higher audio volume.",
        ]
    ),
    Version(
        version: "0.28.0",
        changes: [
            "• Weird workaround to make my Android WiFi hotspot work. Had to ignore an error that shouldn't occur.",
            "• Support for multiple video effects of same kind. (I did cheat a lot before by creating video effects at startup.)",
            "• Fix so torch is not turned off when pressing buttons, or other action that changes the scene.",
        ]
    ),
    Version(
        version: "0.27.0",
        changes: [
            "• Zoom settings.",
            "• More debug logging of SRTLA connections. (Ethernet remained with 2% of uploads after unplugged.)",
            "• Settings storage rework that hopefully does not affect anyone. Should only affect users that upgrade from a really old version.",
        ]
    ),
    Version(
        version: "0.26.0",
        changes: [
            "• Experimental: Try to use all camera lenses. Did not work on my iPhone X, but I think it will work on newer models. The selected mode can be found in the debug log. For example \"Dual camera\" with its zoom and physical cameras.",
            "• Experimental: 0.5x back camera zoom.",
            "• SRTLA statistics with upload percentage per connection type.",
        ]
    ),
    Version(
        version: "0.25.0",
        changes: [
            "• Noise reduction video effect.",
        ]
    ),
    Version(
        version: "0.24.0",
        changes: [
            "• Show third party licenses in About.",
            "• New video effect that randomly picks an effect.",
            "• New \"Triple\" video effect that shows the center of the video three times. Very CPU intensive right now so might be removed or reworked later on.",
            "• Gray buttons instead of blue for less distractions.",
            "• Increased maximum number of buttons from 8 to 10 (as zoom slider was removed).",
            "• BELABOX help in URL view.",
        ]
    ),
    Version(
        version: "0.23.0",
        changes: [
            "• Zoom buttons instead of slider.",
            "• Rework start/stop at enter/exit background. Still problematic.",
            "• Fix audio 100 dB bug.",
        ]
    ),
    Version(
        version: "0.22.0",
        changes: [
            "• Big refactoring. Hopefully didn't introduce too many bugs.",
            "• Import and export settings.",
            "• More SRT URL validation.",
            "• Allow reorder stream entries.",
            "• White viewers and chat icons with text \"Not configured\"  if channel name/id is not configured.",
            "• Higher contrast in scene picker.",
        ]
    ),
    Version(
        version: "0.21.0",
        changes: [
            "• Fix startup crash when default settings are used.",
        ]
    ),
    Version(
        version: "0.20.0",
        changes: [
            "• Show significant messages in a toast.",
            "• Save setting (if valid) when pressing \"Back\".",
        ]
    ),
    Version(
        version: "0.19.0",
        changes: [
            "• First version that works with BELABOX cloud. Both SRT and SRTLA with H.265/HEVC works.",
        ]
    ),
    Version(
        version: "0.18.0",
        changes: [
            "• Use SRT(LA) query parameters.",
        ]
    ),
    Version(
        version: "0.17.0",
        changes: [
            "• SRTLA debug logs.",
            "• Clear log button.",
            "• Enable/disable debug logging.",
        ]
    ),
    Version(
        version: "0.16.0",
        changes: [
            "• H.265/HEVC works. Tested with SRT and SRTLA.",
            "• Disable autocorrection on URL text field.",
        ]
    ),
    Version(
        version: "0.15.0",
        changes: [
            "• Revert multi line URL as submit (pressing return) does not work.",
        ]
    ),
    Version(
        version: "0.14.0",
        changes: [
            "• SRTLA that hopefully works. Only tested locally. Would be great if someone can test it with real setup.",
            "• Audio level in settings.",
            "• Show URL on multiple lines if it doesn't fit on one (for readability).",
        ]
    ),
    Version(
        version: "0.13.0",
        changes: [
            "• Audio level meter local overlay.",
            "• More help in settings.",
        ]
    ),
    Version(
        version: "0.12.0",
        changes: [
            "• Show longer chat names (before truncating).",
            "• SRTLA works (locally, not tested cloud). Fixed prioritization between registered interfaces.",
            "• Always restart stream when transitioning from background to foreground. Seems to fix hangs. Of what I understand video capture is prohibited in background anyway.",
        ]
    ),
]

// swiftlint:enable line_length

struct AboutVersionHistorySettingsView: View {
    var body: some View {
        ScrollView {
            HStack {
                LazyVStack(alignment: .leading) {
                    ForEach(versions, id: \.version) { version in
                        Text(version.version)
                            .font(.title2)
                            .padding()
                        VStack(alignment: .leading) {
                            ForEach(version.changes, id: \.self) { change in
                                Text(change)
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .navigationTitle("Version history")
        .toolbar {
            SettingsToolbar()
        }
    }
}
