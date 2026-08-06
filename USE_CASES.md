# Use Cases

This section provides examples of how to use the `audio` module.


## Sound Config

Here is the full description of the sound config:

```lua
---@class audio.sound
---@field url string|string[] The sound component url or the list of urls to pick a random one
---@field random_pitch number|nil The random pitch in range [0 .. 1]. The sound speed will be randomized in range [1 - random_pitch .. 1 + random_pitch]
---@field play_cooldown number|nil The minimum time in seconds between the sound plays. Default is 4/60. Set 0 to disable
---@field max_instances number|nil The maximum number of simultaneously playing instances. The oldest instances are stopped on overflow
```

Keep the config in a separate file and require it in the place where you init the module:

```lua
-- game/sounds.lua
---@type table<string, audio.sound>
return {
	click = { url = "/sounds#click" },
	coin = { url = { "/sounds#coin_1", "/sounds#coin_2", "/sounds#coin_3" }, random_pitch = 0.1 },
	music = { url = "/sounds#music", play_cooldown = 0 },
}
```

```lua
local audio = require("audio.audio")

audio.init(require("game.sounds"))
```


## Prepare the sounds in the project

The module plays the sound components, so they should exist in the loaded collection:

1. Add the sound files (`.wav` or `.ogg`) to your project.
2. Create the `.sound` component for each sound file and set the `group` field, for example `sfx` or `music`.
3. Add all sound components to a single game object, for example `sounds`, in your bootstrap collection.
4. Use the component urls in the sounds config: `/sounds#click`.

Keeping all sounds in one persistent game object is the simplest way, so any script in the game can play them by id.


## Save the audio state

The state contains the gain of all changed sound groups. Load it **before** the `audio.init` call, so the gains will be applied to the engine on the init.

For this you can use the [Defold Saver](https://github.com/Insality/defold-saver) module.

```lua
local saver = require("saver.saver")
local audio = require("audio.audio")

function init(self)
	saver.init()

	-- Bind the audio state to the save file
	local audio_state = saver.bind_save_state("audio", audio.get_state())
	audio.set_state(audio_state)

	audio.init(require("game.sounds"))
end
```

The `audio.set_gain` calls will change the bound state table, so the gains will be saved automatically.


## Sound settings UI

The gain is linear in the `[0 .. 1]` range, so it can be used directly in the settings sliders:

```lua
local audio = require("audio.audio")

-- Init the slider with the current gain
slider:set_value(audio.get_gain("music"))

slider.on_change_value:subscribe(function(value)
	audio.set_gain("music", value)
end)
```

To mute the whole game, change the gain of the Defold `master` group:

```lua
local function set_muted(is_muted)
	audio.set_gain("master", is_muted and 0 or 1)
end
```


## Music with the fade in and fade out

The `audio.fade` changes the sound gain over time. To fade in the music, start it with the zero gain:

```lua
local MUSIC_FADE_TIME = 1

local function play_music()
	audio.play("music", 0)
	audio.fade("music", 1, MUSIC_FADE_TIME)
end

local function stop_music()
	audio.fade("music", 0, MUSIC_FADE_TIME)
	timer.delay(MUSIC_FADE_TIME, false, function()
		audio.stop("music")
	end)
end
```

The `audio.stop` cancels the current fade of the sound, so the music can be stopped instantly at any moment.

> **Note:** All the fades and delayed plays are processed by a single `timer.delay`, created inside the `audio.init` call. The `audio.fade` and `audio.play_delay` calls only change the numbers, so they will finish even if the game object which started them is deleted. Just call the `audio.init` from a persistent script, for example from your loader.


## Sound variations

The repetitive sounds are the fastest way to annoy the player. Use the list of urls and the random pitch to make them different every time:

```lua
audio.init({
	footstep = {
		url = { "/sounds#footstep_1", "/sounds#footstep_2", "/sounds#footstep_3" },
		random_pitch = 0.15,
		play_cooldown = 0.1,
	},
})

-- Play a random footstep from the list with a random pitch
audio.play("footstep")
```

If you need the exact sound from the list, use the `audio.play_index`. It's useful when the sound depends on the game state, for example the combo counter:

```lua
audio.init({
	combo = {
		url = { "/sounds#combo_1", "/sounds#combo_2", "/sounds#combo_3" },
		play_cooldown = 0,
	},
})

-- The index is clamped to the urls list, so the combo 10 will play the last sound
audio.play_index("combo", combo_counter)
```


## Protect the game from the sound spam

Two configs are used to keep the sound mix clean:

- `play_cooldown` - skip the play if the previous one was too recent. The default value is `4/60` seconds, it filters the duplicated calls in the same frame.
- `max_instances` - restart the sound instead of stacking the new instance over the previous ones.

```lua
audio.init({
	-- The collected coins are played in a burst, keep only 3 of them at once
	coin = {
		url = "/sounds#coin",
		play_cooldown = 0.03,
		max_instances = 3,
	},

	-- The UI click should not be played twice in the same frame
	click = {
		url = "/sounds#click",
	},

	-- The music is a single long sound, no cooldown is required
	music = {
		url = "/sounds#music",
		play_cooldown = 0,
	},
})
```


## Check the sound state

The module counts the playing instances of each sound, so you can check if the sound is still playing:

```lua
local function toggle_music()
	if audio.is_playing("music") then
		audio.stop("music")
	else
		audio.play("music")
	end
end
```


## Delayed play

Schedule a sound to play later and keep the returned handle to cancel it.:

```lua
-- Play the coin sound in 0.5 seconds
local handle = audio.play_delay("coin", 0.5)

-- Cancel if the player left the reward screen before the delay finished
audio.cancel_play_delay(handle)

-- Safe to call again, with nil, or after the sound has already played
audio.cancel_play_delay(handle)
```

If `delay` is zero or negative, the sound is played immediately and `nil` is returned.


## Logging

The module can log its warnings, for example when you try to play an unregistered sound id. Use the [Defold Log](https://github.com/Insality/defold-log) module or provide your own logger:

```lua
local log = require("log.log")
local audio = require("audio.audio")

audio.set_logger(log.get_logger("audio"))

-- Or disable the logging at all
audio.set_logger(nil)
```
