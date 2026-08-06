local logger = require("audio.internal.audio_logger")
local audio_state = require("audio.internal.audio_state")
local audio_internal = require("audio.internal.audio_internal")

---The Defold Audio module.
---Used to register sounds and manage their playback and gain.
---@class audio
local M = {}

local DEFAULT_PLAY_COOLDOWN = 4 / 60


---@param id string
---@param url hash|string|url
---@param gain number|nil
local function play_sound(id, url, gain)
	local runtime = audio_internal.get_runtime()
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		return
	end

	local play_cooldown = sound_config.play_cooldown
	if play_cooldown == nil then
		play_cooldown = DEFAULT_PLAY_COOLDOWN
	end

	local max_instances = sound_config.max_instances
	local playing_instances = runtime.playing[id] or 0
	if max_instances and max_instances > 0 and playing_instances >= max_instances then
		M.stop(id)
		playing_instances = 0
	end

	if play_cooldown > 0 then
		local now = socket.gettime()
		local last_play_time = runtime.last_play_time[id]
		if last_play_time and (now - last_play_time) < play_cooldown then
			return
		end
		runtime.last_play_time[id] = now
	end

	local engine_gain = runtime.last_gains[id] or audio_internal.to_engine_gain(1)
	local speed = 1

	if gain ~= nil then
		engine_gain = audio_internal.to_engine_gain(audio_internal.clamp01(gain))
	end

	if sound_config.random_pitch and sound_config.random_pitch > 0 then
		speed = 1 + (math.random() * 2 - 1) * sound_config.random_pitch
	end

	runtime.props.gain = engine_gain
	runtime.props.speed = speed
	local play_generation = runtime.playing_generation[id] or 0
	runtime.playing[id] = playing_instances + 1
	sound.play(url, runtime.props, function()
		if (runtime.playing_generation[id] or 0) ~= play_generation then
			return
		end
		local current_instances = runtime.playing[id] or 0
		runtime.playing[id] = math.max(0, current_instances - 1)
	end)

	audio_internal.set_sound_gain_engine(id, engine_gain)
end


-- Setup
---Initialize the audio module with the sounds config and apply the current group gains
---		audio.init(require("game.sounds"))
---		audio.init({
---			click = { url = "/sounds#click" },
---			coin = { url = { "/sounds#coin_1", "/sounds#coin_2" }, random_pitch = 0.1 },
---		})
---@param sounds table<string, audio.sound>|nil Sound configs by sound id. Can be nil to init without sounds
function M.init(sounds)
	audio_internal.set_sounds(sounds)

	for group, value in pairs(audio_state.get_state().groups) do
		sound.set_group_gain(group, audio_internal.to_engine_gain(value))
	end

	logger:info("Audio module initialized", {
		sounds = audio_internal.get_sounds_count(),
		groups = audio_internal.count_table_entries(audio_state.get_state().groups),
	})
end


---Customize the logging mechanism used by Audio module. You can use **Defold Log** library or provide a custom logger.
---		audio.set_logger(log.get_logger("audio"))
---@param logger_instance audio.logger|table|nil A logger object that follows the specified logging interface, including methods for `trace`, `debug`, `info`, `warn`, `error`. Pass `nil` to remove the logger
function M.set_logger(logger_instance)
	logger.set_logger(logger_instance)
end


-- Save and load state
---Get the current state for serialization. Contains the gain of all changed sound groups
---		saver.bind_save_state("audio", audio.get_state())
---@return audio.state
function M.get_state()
	return audio_state.get_state()
end


---Set the state (for deserialization). Call it before `audio.init` to restore the saved group gains
---		audio.set_state(loaded_state)
---		audio.init(require("game.sounds"))
---@param new_state audio.state Previously saved state
function M.set_state(new_state)
	audio_state.set_state(new_state)
end


---Reset the state to default and clear all runtime data. The registered sounds are kept
function M.reset_state()
	audio_state.reset()
	audio_internal.reset_runtime()
end


-- Playback
---Play the sound by id. If the sound config contains a list of urls, a random one will be picked
---		audio.play("click")
---		audio.play("coin", 0.5)
---@param id string The sound id from the sounds config
---@param gain number|nil Linear gain in range [0 .. 1]. Default is the last used gain of this sound
function M.play(id, gain)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to play an unregistered sound", id)
		return
	end

	play_sound(id, audio_internal.choose_url(sound_config), gain)
end


---Play the exact sound from the sound config urls list by index
---		audio.play_with_index("footstep", 2)
---		audio.play_with_index("footstep", 2, 0.5)
---@param id string The sound id from the sounds config
---@param index number Index of the url in the sound config urls list, starts from 1
---@param gain number|nil Linear gain in range [0 .. 1]. Default is the last used gain of this sound
function M.play_with_index(id, index, gain)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to play an unregistered sound", id)
		return
	end

	play_sound(id, audio_internal.get_url_at_index(sound_config, index or 1), gain)
end


---Stop all playing instances of the sound
---		audio.stop("music")
---@param id string The sound id from the sounds config
function M.stop(id)
	local runtime = audio_internal.get_runtime()
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to stop an unregistered sound", id)
		return
	end

	runtime.fades[id] = nil
	runtime.playing_generation[id] = (runtime.playing_generation[id] or 0) + 1

	local urls = sound_config.url
	if type(urls) == "table" then
		for _, url in ipairs(urls) do
			sound.stop(url)
		end
		runtime.playing[id] = 0
		return
	end

	sound.stop(urls)
	runtime.playing[id] = 0
end


---Check if the sound is playing now
---		if not audio.is_playing("music") then
---			audio.play("music")
---		end
---@param id string The sound id from the sounds config
---@return boolean is_playing True if at least one instance of the sound is playing
function M.is_playing(id)
	return (audio_internal.get_runtime().playing[id] or 0) > 0
end


---Fade the sound gain to the target value over time. Useful to fade in and out the music
---		audio.fade("music", 0, 1) -- Fade out the music in 1 second
---		audio.fade("music", 1, 2) -- Fade in the music in 2 seconds
---@param id string The sound id from the sounds config
---@param target_gain number Target linear gain in range [0 .. 1]
---@param time number|nil Fade time in seconds. If not set, the gain is applied instantly
function M.fade(id, target_gain, time)
	local runtime = audio_internal.get_runtime()
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to fade an unregistered sound", id)
		return
	end

	local from = runtime.last_gains[id]
	if not from then
		from = audio_internal.to_engine_gain(1)
		audio_internal.set_sound_gain_engine(id, from)
	end

	local target = audio_internal.to_engine_gain(audio_internal.clamp01(target_gain))
	if not time or time <= 0 then
		runtime.fades[id] = nil
		audio_internal.set_sound_gain_engine(id, target)
		return
	end

	local step = math.abs(target - from) * audio_internal.get_fade_dt() / time
	if step <= 0 then
		runtime.fades[id] = nil
		audio_internal.set_sound_gain_engine(id, target)
		return
	end

	runtime.fades[id] = {
		id = id,
		value = from,
		target = target,
		step = step,
	}

	audio_internal.ensure_fade_timer()
end


-- Sound Groups
---Set the linear gain of the sound group. The value is stored in the state
---		audio.set_gain("music", 0.5)
---		audio.set_gain("sfx", 0.8)
---@param group string The sound group name, as it set in the sound components
---@param linear_value number|nil Linear gain in range [0 .. 1]. Default is 1
function M.set_gain(group, linear_value)
	local value = audio_internal.clamp01(linear_value)
	audio_state.set_group_gain(group, value)
	sound.set_group_gain(group, audio_internal.to_engine_gain(value))
end


---Get the linear gain of the sound group
---		local music_gain = audio.get_gain("music")
---@param group string The sound group name, as it set in the sound components
---@return number gain Linear gain in range [0 .. 1]. Default is 1
function M.get_gain(group)
	return audio_state.get_group_gain(group)
end


return M
