# audio API

> at /audio/audio.lua

The Defold Audio module.
Used to register sounds and manage their playback and gain.

## Functions

- [init](#init)
- [final](#final)
- [update](#update)
- [on_message](#on_message)
- [add_sounds](#add_sounds)
- [remove_sounds](#remove_sounds)
- [set_logger](#set_logger)
- [get_state](#get_state)
- [set_state](#set_state)
- [reset_state](#reset_state)
- [play](#play)
- [play_index](#play_index)
- [play_delay](#play_delay)
- [cancel_play_delay](#cancel_play_delay)
- [stop](#stop)
- [set_playing](#set_playing)
- [set_pan](#set_pan)
- [is_playing](#is_playing)
- [fade](#fade)
- [set_gain](#set_gain)
- [get_gain](#get_gain)

## Types

- [audio.sound](#audiosound)
- [audio.state](#audiostate)



### init

---
```lua
audio.init()
```

 Setup
Initialize the audio host. Called by `audio.script`. Place that script on a game object
in the collection that should own the playback. Register the sounds with `audio.add_sounds` from your scripts

- **Example Usage:**

```lua
-- audio.script
function init(self)
	audio.init()
end

function update(self, dt)
	audio.update(dt)
end
```

### final

---
```lua
audio.final()
```

Clear the audio host if this script is the current one. Called by `audio.script` on final

### update

---
```lua
audio.update(dt)
```

Update the fades and delayed plays. Called by `audio.script`

- **Parameters:**
	- `dt` *(number)*: Frame delta time in seconds

### on_message

---
```lua
audio.on_message(message_id, message)
```

Handle the play messages posted to `audio.script`

- **Parameters:**
	- `message_id` *(hash)*
	- `message` *(table)*

### add_sounds

---
```lua
audio.add_sounds(sounds)
```

Register the additional sounds. The sound urls are resolved in the collection
of the calling script, so it's the way to register the sounds which are placed inside a collection proxy

- **Parameters:**
	- `sounds` *(table<string, audio.sound>)*: Sound configs by sound id. The sounds with the same id are replaced

- **Example Usage:**

```lua
audio.add_sounds(require("game.sounds"))
audio.add_sounds(require("game.level_sounds"))
```

### remove_sounds

---
```lua
audio.remove_sounds(sounds)
```

Unregister the sounds, previously added with `audio.add_sounds`. Pass the same sounds table.
The sound replaced by another `audio.add_sounds` call with the same id is kept.
The fades and delayed plays of the removed sounds are canceled. The sounds in the fade out of `audio.stop` are stopped instantly. The other playing sounds are not stopped,
call `audio.stop` before, if the sounds should stop now

- **Parameters:**
	- `sounds` *(table<string, audio.sound>)*: The same sounds table, passed to `audio.add_sounds`

- **Example Usage:**

```lua
audio.remove_sounds(require("game.window_sounds"))
```

### set_logger

---
```lua
audio.set_logger([logger_instance])
```

Customize the logging mechanism used by Audio module. You can use **Defold Log** library or provide a custom logger.

- **Parameters:**
	- `[logger_instance]` *(audio.logger|table|nil)*: A logger object that follows the specified logging interface, including methods for `trace`, `debug`, `info`, `warn`, `error`. Pass `nil` to remove the logger

- **Example Usage:**

```lua
audio.set_logger(log.get_logger("audio"))
```

### get_state

---
```lua
audio.get_state()
```

 Save and load state
Get the current state for serialization. Contains the gain of all changed sound groups

- **Returns:**
	- `` *(audio.state)*:

- **Example Usage:**

```lua
saver.bind_save_state("audio", audio.get_state())
```

### set_state

---
```lua
audio.set_state(new_state)
```

Set the state (for deserialization). The group gains are applied to the engine immediately

- **Parameters:**
	- `new_state` *(audio.state)*: Previously saved state

- **Example Usage:**

```lua
audio.set_state(loaded_state)
```

### reset_state

---
```lua
audio.reset_state()
```

Reset the state to default and clear all runtime data. The registered sounds and the audio host are kept

### play

---
```lua
audio.play(id, [gain])
```

 Playback
Play the sound by id. If the sound config contains a list of urls, a random one will be picked.
If the sound config has the `fade_in` and the sound is not playing, the sound is faded in from the zero gain.
The sound is started in `audio.script`

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `[gain]` *(number|nil)*: Gain in range [0 .. 1]. Default is the last used gain of this sound

- **Example Usage:**

```lua
audio.play("click")
audio.play("coin", 0.5)
```

### play_index

---
```lua
audio.play_index(id, index, [gain])
```

Play the exact sound from the sound config urls list by index.
The sound is started in `audio.script`

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `index` *(number)*: Index of the url in the sound config urls list, starts from 1
	- `[gain]` *(number|nil)*: Gain in range [0 .. 1]. Default is the last used gain of this sound

- **Example Usage:**

```lua
audio.play_index("footstep", 2)
audio.play_index("footstep", 2, 0.5)
```

### play_delay

---
```lua
audio.play_delay(id, delay, [gain])
```

Schedule the sound to play after the delay. Uses an internal remaining-time counter on the `audio.script` update, not a separate timer

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `delay` *(number)*: Delay in seconds before the sound is played
	- `[gain]` *(number|nil)*: Gain in range [0 .. 1]. Default is the last used gain of this sound

- **Returns:**
	- `handle` *(number|nil)*: Handle to cancel the delayed play with `audio.cancel_play_delay`. Nil if the sound is not registered or the delay is zero or negative

- **Example Usage:**

```lua
local handle = audio.play_delay("click", 0.5)
local handle = audio.play_delay("coin", 1, 0.5)
```

### cancel_play_delay

---
```lua
audio.cancel_play_delay([handle])
```

Cancel a delayed play by handle. Idempotent: safe to call multiple times, with nil, or after the sound has already played

- **Parameters:**
	- `[handle]` *(number|nil)*: Handle returned by `audio.play_delay`

- **Example Usage:**

```lua
local handle = audio.play_delay("click", 0.5)
audio.cancel_play_delay(handle)
```

### stop

---
```lua
audio.stop(id, [fade_out])
```

Stop all playing instances of the sound. With the fade out time the sound is faded out and stopped after the fade.
The `audio.play`, `audio.set_playing` or `audio.fade` during the fade out cancels the stop.
After the stop the sound keeps its gain before the fade out, so the next play is not silent

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `[fade_out]` *(number|nil)*: Fade out time in seconds. Default is the `fade_out` from the sound config. Pass 0 to stop instantly

- **Example Usage:**

```lua
audio.stop("music")
audio.stop("music", 1) -- Fade out the music in 1 second and stop it
```

### set_playing

---
```lua
audio.set_playing(id, is_playing, [fade_time])
```

Play or stop the sound with the fade, depending on the state. Safe to call every frame with the same state.
The state change in the middle of the fade turns the fade around from the current gain, without the sound restart.
Useful for the looped sounds which depend on the game state, like the engine hum or the hover buzz

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `is_playing` *(boolean)*: Should the sound be playing
	- `[fade_time]` *(number|nil)*: Fade time in seconds. Default is the `fade_in` or `fade_out` from the sound config

- **Example Usage:**

```lua
audio.set_playing("buzz", is_hovered)
audio.set_playing("buzz", is_hovered, 0.2)
```

### set_pan

---
```lua
audio.set_pan(id, pan)
```

Set the pan of the sound. The pan is kept by the sound component, so the next plays use it too.
Cheap to call every frame: the engine is not called if the pan is not changed

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `pan` *(number)*: Pan in range [-1 .. 1]. -1 is the left channel, 1 is the right one

- **Example Usage:**

```lua
audio.set_pan("buzz", -0.5)
```

### is_playing

---
```lua
audio.is_playing(id)
```

Check if the sound is playing now

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config

- **Returns:**
	- `is_playing` *(boolean)*: True if at least one instance of the sound is playing

- **Example Usage:**

```lua
if not audio.is_playing("music") then
	audio.play("music")
end
```

### fade

---
```lua
audio.fade(id, target_gain, [time])
```

Fade the sound gain to the target value over time. Useful to fade in and out the music.
It cancels the stop after the fade out of `audio.stop`

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `target_gain` *(number)*: Target gain in range [0 .. 1]
	- `[time]` *(number|nil)*: Fade time in seconds. If not set, the gain is applied instantly

- **Example Usage:**

```lua
audio.fade("music", 0, 1) -- Fade out the music in 1 second
audio.fade("music", 1, 2) -- Fade in the music in 2 seconds
```

### set_gain

---
```lua
audio.set_gain(group, [gain])
```

 Sound Groups
Set the gain of the sound group. The value is stored in the state

- **Parameters:**
	- `group` *(string)*: The sound group name, as it set in the sound components
	- `[gain]` *(number|nil)*: Gain in range [0 .. 1]. Default is 1

- **Example Usage:**

```lua
audio.set_gain("music", 0.5)
audio.set_gain("sfx", 0.8)
```

### get_gain

---
```lua
audio.get_gain(group)
```

Get the gain of the sound group

- **Parameters:**
	- `group` *(string)*: The sound group name, as it set in the sound components

- **Returns:**
	- `gain` *(number)*: Gain in range [0 .. 1]. Default is 1

- **Example Usage:**

```lua
local music_gain = audio.get_gain("music")
```


### audio.sound

---
The sound config, used to register the sound in the audio module

```lua
---@class audio.sound
---@field url string|string[]
---@field random_pitch number|nil
---@field play_cooldown number|nil
---@field max_instances number|nil
---@field fade_in number|nil
---@field fade_out number|nil
```

- **Fields:**
	- `url` *(string|string[])*: The sound component url or the list of urls to pick a random one. Relative urls like `/sounds#click` are resolved in the collection where `audio.add_sounds` was called
	- `random_pitch` *(number|nil)*: The random pitch in range [0 .. 1]. The sound speed will be randomized in range [1 - random_pitch .. 1 + random_pitch]
	- `play_cooldown` *(number|nil)*: The minimum time in seconds between the sound plays. Default is 4/60. Set 0 to disable
	- `max_instances` *(number|nil)*: The maximum number of simultaneously playing instances. The oldest instances are stopped on overflow
	- `fade_in` *(number|nil)*: The fade in time in seconds, used by `audio.play` and `audio.set_playing` when the sound is not playing yet
	- `fade_out` *(number|nil)*: The fade out time in seconds, used by `audio.stop` and `audio.set_playing`. The sound is stopped after the fade

### audio.state

---
The audio module state, can be saved and loaded between game sessions

```lua
---@class audio.state
---@field groups table<string, number>
```

- **Fields:**
	- `groups` *(table<string, number>)*: The gain of the sound groups by group name
