# Command prefixes and aliases

Choose enabled prefixes in Settings → Chat → Bot → Command prefixes. The default
is `!`. You can enable `.` and `/` as well, or use either without `!`. Keep at
least one prefix enabled; use the Bot switch to turn the bot off.

Every enabled prefix works with the same commands and aliases. For example,
`!moblin scene Main`, `.moblin scene Main` and `/moblin scene Main` invoke the
same command when their prefixes are enabled. An alias `!screen` with replacement
`!moblin scene Screen` also works as `.screen` and `/screen`. Existing aliases
need no changes. Settings show the enabled spellings; saved aliases and
replacements retain the canonical `!` representation.

Permissions and cooldowns apply equally to all prefixes and aliases. Custom
chat filters still match their configured literal text. With text-to-speech Filter
enabled, bang messages and messages starting with any enabled prefix are skipped.
Slash commands work
only when the sending chat client delivers them as chat messages; Moblin cannot
process input that a client intercepts locally.

The examples below use the default `!` prefix. Substitute an enabled prefix.

# Moblin chat bot help

| Command | Description |
|---------|-------------|
| !moblin obs fix   | Fix OBS input.        |
| !moblin alert \<name> | Trigger alerts. Configure alert names in alert widgets. |
| !moblin fax \<url> | Fax the streamer images. |
| !moblin snapshot | Take snapshot. |
| !moblin snapshot \<message> | Take snapshot showing given message to the streamer. |
| !moblin map zoom out | Zoom out map widget temporarily. |
| !moblin tts on | Turn on chat text to speech. |
| !moblin tts off | Turn off chat text to speech. |
| !moblin say \<message> | Say given message. |
| !moblin zoom \<x> | Set zoom for the current camera. |
| !moblin scene \<name> | Change scene. |
| !moblin gimbal preset \<name> | Move to given gimbal preset. |
| !moblin stream title \<title> | Set stream title. |
| !moblin widget \<name> timer \<number> add \<seconds> | Add time to a timer. |
| !moblin ai ask \<question> | Ask AI a question. |
| !moblin custom \<name> | Send the text of given custom command to chat. Configure custom commands in Moblin. |
| !moblin mute | Mute audio. |
| !moblin unmute | Unmute audio. |
| !moblin torch on | Turn the torch on. |
| !moblin torch off | Turn the torch off. |
| !moblin torch level \<level> | Set torch level, from 1 to 100. |
| !moblin vibrate on [\<seconds>] [\<intensity>] [\<sharpness>] | Vibrate the phone. Until turned off if no seconds is given. Intensity and sharpness from 1 to 100, default 100 and 50. |
| !moblin vibrate off | Stop vibrating the phone. |
| !moblin music add <song> | Add a song. Free text search or share link. |
| !moblin music play | Play. |
| !moblin music pause | Pause. |
| !moblin music next [\<count>] | Next song(s). |
| !moblin music previous [\<count>] | Previous song(s). |
| !moblin music status | Show status. |
| !moblin music clear | Clear the queue. |
| !moblin tesla trunk open | Open the trunk. |
| !moblin tesla trunk close | Close the trunk. |
| !moblin tesla media next | Next track. |
| !moblin tesla media previous | Previous track. |
| !moblin tesla media toggle-playback | Toggle playback. |
| !moblin filter movie on | Turn on the movie filter. |
| !moblin filter movie off | Turn off the movie filter. |
| !moblin filter grayscale on | Turn on the grayscale filter. |
| !moblin filter grayscale off | Turn off the grayscale filter. |
| !moblin filter sepia on | Turn on the sepia filter. |
| !moblin filter sepia off | Turn off the sepia filter. |
| !moblin filter triple on | Turn on the triple filter. |
| !moblin filter triple off | Turn off the triple filter. |
| !moblin filter twin on | Turn on the twin filter. |
| !moblin filter twin off | Turn off the twin filter. |
| !moblin filter pixellate on | Turn on the pixellate filter. |
| !moblin filter pixellate off | Turn off the pixellate filter. |
| !moblin filter 4:3 on | Turn on the 4:3 filter. |
| !moblin filter 4:3 off | Turn off the 4:3 filter. |
| !moblin filter whirlpool on | Turn on the whirlpool filter. |
| !moblin filter whirlpool off | Turn off the whirlpool filter. |
| !moblin filter pinch on | Turn on the pinch filter. |
| !moblin filter pinch off | Turn off the pinch filter. |
| !moblin reaction fireworks | Trigger Apple fireworks reaction. |
| !moblin reaction balloons | Trigger Apple balloons reaction. |
| !moblin reaction hearts | Trigger Apple hearts reaction. |
| !moblin reaction confetti | Trigger Apple confetti reaction. |
| !moblin reaction lasers | Trigger Apple lasers reaction. |
| !moblin reaction rain | Trigger Apple rain reaction. |
| !moblin reaction glasses | Trigger glasses reaction. |
| !moblin reaction sparkle | Trigger sparkle reaction. |
| !moblin macro run \<name> | Run given macro. |
| !moblin macro cancel \<name> | Cancel given macro. |
