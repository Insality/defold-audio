# audio API

> at /audio/audio.lua

The Defold Audio module.
Used to register sounds and manage their playback and gain.

## Functions

- [init](#init)
- [set_logger](#set_logger)
- [get_state](#get_state)
- [set_state](#set_state)
- [reset_state](#reset_state)
- [play](#play)
- [play_index](#play_index)
- [play_delay](#play_delay)
- [cancel_play_delay](#cancel_play_delay)
- [stop](#stop)
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
audio.init([sounds])
```

 Setup
Initialize the audio module with the sounds config and apply the current group gains.
It creates the single module timer for fades and delayed plays, so call it from a persistent script, for example from your loader

- **Parameters:**
	- `[sounds]` *(table<string, audio.sound>|nil)*: Sound configs by sound id. Can be nil to init without sounds

- **Example Usage:**

```lua
audio.init(require("game.sounds"))
audio.init({
	click = { url = "main:/sounds#click" },
	coin = { url = { "main:/sounds#coin_1", "main:/sounds#coin_2" }, random_pitch = 0.1 },
})
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

Set the state (for deserialization). Call it before `audio.init` to restore the saved group gains

- **Parameters:**
	- `new_state` *(audio.state)*: Previously saved state

- **Example Usage:**

```lua
audio.set_state(loaded_state)
audio.init(require("game.sounds"))
```

### reset_state

---
```lua
audio.reset_state()
```

Reset the state to default and clear all runtime data. The registered sounds and the module timer are kept

### play

---
```lua
audio.play(id, [gain])
```

 Playback
Play the sound by id. If the sound config contains a list of urls, a random one will be picked

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `[gain]` *(number|nil)*: Linear gain in range [0 .. 1]. Default is the last used gain of this sound

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

Play the exact sound from the sound config urls list by index

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `index` *(number)*: Index of the url in the sound config urls list, starts from 1
	- `[gain]` *(number|nil)*: Linear gain in range [0 .. 1]. Default is the last used gain of this sound

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

Schedule the sound to play after the delay. Uses an internal remaining-time counter on the module tick, not a separate timer

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `delay` *(number)*: Delay in seconds before the sound is played
	- `[gain]` *(number|nil)*: Linear gain in range [0 .. 1]. Default is the last used gain of this sound

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
audio.stop(id)
```

Stop all playing instances of the sound

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config

- **Example Usage:**

```lua
audio.stop("music")
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

Fade the sound gain to the target value over time. Useful to fade in and out the music

- **Parameters:**
	- `id` *(string)*: The sound id from the sounds config
	- `target_gain` *(number)*: Target linear gain in range [0 .. 1]
	- `[time]` *(number|nil)*: Fade time in seconds. If not set, the gain is applied instantly

- **Example Usage:**

```lua
audio.fade("music", 0, 1) -- Fade out the music in 1 second
audio.fade("music", 1, 2) -- Fade in the music in 2 seconds
```

### set_gain

---
```lua
audio.set_gain(group, [linear_value])
```

 Sound Groups
Set the linear gain of the sound group. The value is stored in the state

- **Parameters:**
	- `group` *(string)*: The sound group name, as it set in the sound components
	- `[linear_value]` *(number|nil)*: Linear gain in range [0 .. 1]. Default is 1

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

Get the linear gain of the sound group

- **Parameters:**
	- `group` *(string)*: The sound group name, as it set in the sound components

- **Returns:**
	- `gain` *(number)*: Linear gain in range [0 .. 1]. Default is 1

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
```

- **Fields:**
	- `url` *(string|string[])*: The sound component url or the list of urls to pick a random one. Prefer a full url with the socket (`main:/sounds#click`). Relative urls resolve to the caller collection for `play`/`stop`, and to the `audio.init` collection for `play_delay`/`fade`
	- `random_pitch` *(number|nil)*: The random pitch in range [0 .. 1]. The sound speed will be randomized in range [1 - random_pitch .. 1 + random_pitch]
	- `play_cooldown` *(number|nil)*: The minimum time in seconds between the sound plays. Default is 4/60. Set 0 to disable
	- `max_instances` *(number|nil)*: The maximum number of simultaneously playing instances. The oldest instances are stopped on overflow

### audio.state

---
The audio module state, can be saved and loaded between game sessions

```lua
---@class audio.state
---@field groups table<string, number>
```

- **Fields:**
	- `groups` *(table<string, number>)*: The linear gain of the sound groups by group name
