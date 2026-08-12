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
---Update the module fades and delayed plays. Called by the module update timer
function M.update()
	local runtime = audio_internal.get_runtime()
	if next(runtime.fades) ~= nil then
		audio_internal.update_fades()
	end

	if next(runtime.delayed_plays) ~= nil then
		local dt = audio_internal.get_update_dt()
		for handle, delayed in pairs(runtime.delayed_plays) do
			delayed.remaining = delayed.remaining - dt
			if delayed.remaining <= 0 then
				runtime.delayed_plays[handle] = nil
				M.play(delayed.id, delayed.gain)
			end
		end
	end
end


---Initialize the audio module with the sounds config and apply the current group gains.
---It creates the single module timer for fades and delayed plays, so call it from a persistent script, for example from your loader.
---The relative sound urls like `/sounds#click` are resolved in the collection of the calling script
---		audio.init(require("game.sounds"))
---		audio.init({
---			click = { url = "main:/sounds#click" },
---			coin = { url = { "main:/sounds#coin_1", "main:/sounds#coin_2" }, random_pitch = 0.1 },
---		})
---@param sounds table<string, audio.sound>|nil Sound configs by sound id. Can be nil to init without sounds
function M.init(sounds)
	audio_internal.set_sounds(sounds)
	audio_internal.create_update_timer(M.update)

	for group, value in pairs(audio_state.get_state().groups) do
		sound.set_group_gain(group, audio_internal.to_engine_gain(value))
	end

	logger:info("Audio module initialized", {
		sounds = audio_internal.get_sounds_count(),
		groups = audio_internal.count_table_entries(audio_state.get_state().groups),
	})
end


---Register the additional sounds after the `audio.init` call. The sound urls are resolved in the collection
---of the calling script, so it's the way to register the sounds which are placed inside a collection proxy
---		audio.add_sounds(require("game.level_sounds"))
---@param sounds table<string, audio.sound> Sound configs by sound id. The sounds with the same id are replaced
function M.add_sounds(sounds)
	audio_internal.add_sounds(sounds)

	logger:info("Audio sounds added", {
		sounds = audio_internal.get_sounds_count(),
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


---Reset the state to default and clear all runtime data. The registered sounds and the module timer are kept
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
---		audio.play_index("footstep", 2)
---		audio.play_index("footstep", 2, 0.5)
---@param id string The sound id from the sounds config
---@param index number Index of the url in the sound config urls list, starts from 1
---@param gain number|nil Linear gain in range [0 .. 1]. Default is the last used gain of this sound
function M.play_index(id, index, gain)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to play an unregistered sound", id)
		return
	end

	play_sound(id, audio_internal.get_url_at_index(sound_config, index or 1), gain)
end


---Schedule the sound to play after the delay. Uses an internal remaining-time counter on the module tick, not a separate timer
---		local handle = audio.play_delay("click", 0.5)
---		local handle = audio.play_delay("coin", 1, 0.5)
---@param id string The sound id from the sounds config
---@param delay number Delay in seconds before the sound is played
---@param gain number|nil Linear gain in range [0 .. 1]. Default is the last used gain of this sound
---@return number|nil handle Handle to cancel the delayed play with `audio.cancel_play_delay`. Nil if the sound is not registered or the delay is zero or negative
function M.play_delay(id, delay, gain)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to play an unregistered sound", id)
		return nil
	end

	if not delay or delay <= 0 then
		M.play(id, gain)
		return nil
	end

	return audio_internal.schedule_delayed_play(id, delay, gain)
end


---Cancel a delayed play by handle. Idempotent: safe to call multiple times, with nil, or after the sound has already played
---		local handle = audio.play_delay("click", 0.5)
---		audio.cancel_play_delay(handle)
---@param handle number|nil Handle returned by `audio.play_delay`
function M.cancel_play_delay(handle)
	audio_internal.cancel_delayed_play(handle)
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

	audio_internal.for_each_url(sound_config, function(url)
		sound.stop(url)
	end)
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

	local step = math.abs(target - from) * audio_internal.get_update_dt() / time
	if step <= 0 then
		runtime.fades[id] = nil
		audio_internal.set_sound_gain_engine(id, target)
		return
	end

	runtime.fades[id] = {
		value = from,
		target = target,
		step = step,
	}
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
