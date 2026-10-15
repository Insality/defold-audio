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
---@param fade_in number|nil Fade in time, used if the sound is not playing or is stopping now
---@param is_skip_cooldown boolean|nil
local function play_sound(id, url, gain, fade_in, is_skip_cooldown)
	local runtime = audio_internal.get_runtime()
	if not audio_internal.has_host() then
		logger:warn("Audio host is missing. Add audio.script to a persistent game object", id)
		return
	end

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
		audio_internal.stop_sound(id)
		playing_instances = 0
	end

	if play_cooldown > 0 and not is_skip_cooldown then
		local now = socket.gettime()
		local last_play_time = runtime.last_play_time[id]
		if last_play_time and (now - last_play_time) < play_cooldown then
			return
		end
		runtime.last_play_time[id] = now
	end

	local sound_gain = audio_internal.get_base_gain(id)
	local speed = 1

	if gain ~= nil then
		sound_gain = audio_internal.clamp01(gain)
	end

	-- The play cancels the stop after the fade out. The new instance continues from the current gain
	local start_gain = sound_gain
	local is_stopping = audio_internal.is_stopping(id)
	if fade_in and fade_in > 0 and (playing_instances == 0 or is_stopping) then
		start_gain = 0
		if playing_instances > 0 then
			start_gain = runtime.last_gains[id] or 0
		end
		runtime.last_gains[id] = start_gain
		audio_internal.start_fade(id, sound_gain, fade_in, sound_gain)
	elseif is_stopping then
		runtime.fades[id] = nil
	end

	if sound_config.random_pitch and sound_config.random_pitch > 0 then
		speed = 1 + (math.random() * 2 - 1) * sound_config.random_pitch
	end

	local play_generation = runtime.playing_generation[id] or 0
	runtime.playing[id] = playing_instances + 1
	audio_internal.request_play({
		id = id,
		url = url,
		gain = start_gain,
		speed = speed,
		generation = play_generation,
	})

	runtime.last_gains[id] = start_gain
end


-- Setup
---Update the module fades and delayed plays. Called by `audio.script`
---@param dt number Frame delta time in seconds
function M.update(dt)
	if not dt or dt <= 0 then
		return
	end

	local runtime = audio_internal.get_runtime()
	if next(runtime.fades) ~= nil then
		audio_internal.update_fades(dt)
	end

	if next(runtime.delayed_plays) ~= nil then
		for handle, delayed in pairs(runtime.delayed_plays) do
			delayed.remaining = delayed.remaining - dt
			if delayed.remaining <= 0 then
				runtime.delayed_plays[handle] = nil
				M.play(delayed.id, delayed.gain)
			end
		end
	end
end


---Initialize the audio host. Called by `audio.script`
function M.init()
	audio_internal.bind_host(msg.url())

	for group, value in pairs(audio_state.get_state().groups) do
		sound.set_group_gain(group, value)
	end

	logger:info("Audio module initialized", {
		sounds = audio_internal.get_sounds_count(),
		groups = audio_internal.count_table_entries(audio_state.get_state().groups),
	})
end


---Clear the audio host if this script is the current one. Called by `audio.script` on final
function M.final()
	audio_internal.unbind_host(msg.url())
end


---Handle the play messages posted to `audio.script`
---@param message_id hash
---@param message table
function M.on_message(message_id, message)
	if message_id == audio_internal.MSG_PLAY then
		audio_internal.handle_play(message)
	end
end


---Register the additional sounds. The sound urls are resolved in the collection
---of the calling script, so it's the way to register the sounds which are placed inside a collection proxy
---		audio.add_sounds(require("game.sounds"))
---		audio.add_sounds(require("game.level_sounds"))
---@param sounds table<string, audio.sound> Sound configs by sound id. The sounds with the same id are replaced
function M.add_sounds(sounds)
	audio_internal.add_sounds(sounds)

	logger:info("Audio sounds added", {
		sounds = audio_internal.get_sounds_count(),
	})
end


---Unregister the sounds, previously added with `audio.add_sounds`. Pass the same sounds table.
---The sound replaced by another `audio.add_sounds` call with the same id is kept.
---The fades and delayed plays of the removed sounds are canceled. The sounds in the fade out of `audio.stop` are stopped instantly. The other playing sounds are not stopped,
---call `audio.stop` before, if the sounds should stop now
---		audio.remove_sounds(require("game.window_sounds"))
---@param sounds table<string, audio.sound> The same sounds table, passed to `audio.add_sounds`
function M.remove_sounds(sounds)
	audio_internal.remove_sounds(sounds)

	logger:info("Audio sounds removed", {
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


---Set the state (for deserialization). The group gains are applied to the engine immediately
---		audio.set_state(loaded_state)
---@param new_state audio.state Previously saved state
function M.set_state(new_state)
	audio_state.set_state(new_state)

	for group, value in pairs(audio_state.get_state().groups) do
		sound.set_group_gain(group, value)
	end
end


---Reset the state to default and clear all runtime data. The registered sounds and the audio host are kept
function M.reset_state()
	audio_state.reset()
	audio_internal.reset_runtime()
end


-- Playback
---Play the sound by id. If the sound config contains a list of urls, a random one will be picked.
---If the sound config has the `fade_in` and the sound is not playing, the sound is faded in from the zero gain
---		audio.play("click")
---		audio.play("coin", 0.5)
---@param id string The sound id from the sounds config
---@param gain number|nil Gain in range [0 .. 1]. Default is the last used gain of this sound
function M.play(id, gain)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to play an unregistered sound", id)
		return
	end

	play_sound(id, audio_internal.choose_url(sound_config), gain, sound_config.fade_in)
end


---Play the exact sound from the sound config urls list by index
---		audio.play_index("footstep", 2)
---		audio.play_index("footstep", 2, 0.5)
---@param id string The sound id from the sounds config
---@param index number Index of the url in the sound config urls list, starts from 1
---@param gain number|nil Gain in range [0 .. 1]. Default is the last used gain of this sound
function M.play_index(id, index, gain)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to play an unregistered sound", id)
		return
	end

	play_sound(id, audio_internal.get_url_at_index(sound_config, index or 1), gain, sound_config.fade_in)
end


---Schedule the sound to play after the delay. Uses an internal remaining-time counter on the `audio.script` update, not a separate timer
---		local handle = audio.play_delay("click", 0.5)
---		local handle = audio.play_delay("coin", 1, 0.5)
---@param id string The sound id from the sounds config
---@param delay number Delay in seconds before the sound is played
---@param gain number|nil Gain in range [0 .. 1]. Default is the last used gain of this sound
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


---Stop all playing instances of the sound. With the fade out time the sound is faded out and stopped after the fade.
---The `audio.play`, `audio.set_playing` or `audio.fade` during the fade out cancels the stop.
---After the stop the sound keeps its gain before the fade out, so the next play is not silent
---		audio.stop("music")
---		audio.stop("music", 1) -- Fade out the music in 1 second and stop it
---@param id string The sound id from the sounds config
---@param fade_out number|nil Fade out time in seconds. Default is the `fade_out` from the sound config. Pass 0 to stop instantly
function M.stop(id, fade_out)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to stop an unregistered sound", id)
		return
	end

	if fade_out == nil then
		fade_out = sound_config.fade_out
	end

	if not fade_out or fade_out <= 0 or not M.is_playing(id) then
		audio_internal.stop_sound(id)
		return
	end

	-- Keep the current fade out, the repeated stop should not restart it
	if audio_internal.is_stopping(id) then
		return
	end

	local runtime = audio_internal.get_runtime()
	if (runtime.last_gains[id] or 1) <= 0 then
		audio_internal.stop_sound(id)
		return
	end

	audio_internal.start_fade(id, 0, fade_out, audio_internal.get_base_gain(id), true)
end


---Play or stop the sound with the fade, depending on the state. Safe to call every frame with the same state.
---The state change in the middle of the fade turns the fade around from the current gain, without the sound restart.
---Useful for the looped sounds which depend on the game state, like the engine hum or the hover buzz
---		audio.set_playing("buzz", is_hovered)
---		audio.set_playing("buzz", is_hovered, 0.2)
---@param id string The sound id from the sounds config
---@param is_playing boolean Should the sound be playing
---@param fade_time number|nil Fade time in seconds. Default is the `fade_in` or `fade_out` from the sound config
function M.set_playing(id, is_playing, fade_time)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to set playing an unregistered sound", id)
		return
	end

	local is_stopping = audio_internal.is_stopping(id)
	local is_active = M.is_playing(id) and not is_stopping
	if is_playing == is_active then
		return
	end

	if not is_playing then
		M.stop(id, fade_time or sound_config.fade_out or 0)
		return
	end

	local fade_in = fade_time or sound_config.fade_in or 0
	if is_stopping and M.is_playing(id) then
		local base_gain = audio_internal.get_base_gain(id)
		audio_internal.start_fade(id, base_gain, fade_in, base_gain)
		return
	end

	play_sound(id, audio_internal.choose_url(sound_config), nil, fade_in, true)
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


---Fade the sound gain to the target value over time. Useful to fade in and out the music.
---It cancels the stop after the fade out of `audio.stop`
---		audio.fade("music", 0, 1) -- Fade out the music in 1 second
---		audio.fade("music", 1, 2) -- Fade in the music in 2 seconds
---@param id string The sound id from the sounds config
---@param target_gain number Target gain in range [0 .. 1]
---@param time number|nil Fade time in seconds. If not set, the gain is applied instantly
function M.fade(id, target_gain, time)
	local sound_config = audio_internal.get_sound_config(id)
	if not sound_config then
		logger:warn("Attempt to fade an unregistered sound", id)
		return
	end

	audio_internal.start_fade(id, audio_internal.clamp01(target_gain), time)
end


-- Sound Groups
---Set the gain of the sound group. The value is stored in the state
---		audio.set_gain("music", 0.5)
---		audio.set_gain("sfx", 0.8)
---@param group string The sound group name, as it set in the sound components
---@param gain number|nil Gain in range [0 .. 1]. Default is 1
function M.set_gain(group, gain)
	local value = audio_internal.clamp01(gain)
	audio_state.set_group_gain(group, value)
	sound.set_group_gain(group, value)
end


---Get the gain of the sound group
---		local music_gain = audio.get_gain("music")
---@param group string The sound group name, as it set in the sound components
---@return number gain Gain in range [0 .. 1]. Default is 1
function M.get_gain(group)
	return audio_state.get_group_gain(group)
end


return M
