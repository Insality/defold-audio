local logger = require("audio.internal.audio_logger")
local audio_state = require("audio.internal.audio_state")

local MSG_PLAY = hash("audio_play")

---@class audio.internal.fade
---@field value number
---@field target number
---@field remaining number

---@class audio.internal.delayed_play
---@field id string
---@field remaining number
---@field gain number|nil

---The sound config, used to register the sound in the audio module
---@class audio.sound
---@field url string|string[] The sound component url or the list of urls to pick a random one. Relative urls like `/sounds#click` are resolved in the collection where `audio.add_sounds` was called
---@field random_pitch number|nil The random pitch in range [0 .. 1]. The sound speed will be randomized in range [1 - random_pitch .. 1 + random_pitch]
---@field play_cooldown number|nil The minimum time in seconds between the sound plays. Default is 4/60. Set 0 to disable
---@field max_instances number|nil The maximum number of simultaneously playing instances. The oldest instances are stopped on overflow

---@class audio.internal.runtime
---@field sounds table<string, audio.sound>
---@field fades table<string, audio.internal.fade>
---@field delayed_plays table<number, audio.internal.delayed_play>
---@field host_url url|nil
---@field next_delay_handle number
---@field last_gains table<string, number>
---@field last_play_time table<string, number>
---@field playing table<string, number>
---@field playing_generation table<string, number>
---@field props table<string, number>

---@class audio.internal.api
---@field MSG_PLAY hash
local M = {}

M.MSG_PLAY = MSG_PLAY

---@type audio.internal.runtime
local runtime = {
	sounds = {},
	fades = {},
	delayed_plays = {},
	host_url = nil,
	next_delay_handle = 1,
	last_gains = {},
	last_play_time = {},
	playing = {},
	playing_generation = {},
	props = { gain = 1, speed = 1 },
}


---Clamp the value to the [0 .. 1] range. The vmath.clamp is not used here to keep the double precision
---@param value number|nil
---@return number
function M.clamp01(value)
	value = value or audio_state.DEFAULT_GAIN

	if value < 0 then
		return 0
	end

	if value > 1 then
		return 1
	end

	return value
end


---The engine gain is not linear, so the linear value is converted to the engine one
---@param linear_value number
---@return number
function M.to_engine_gain(linear_value)
	return linear_value * linear_value
end


---@param sound_config audio.sound
---@return hash|string|url
function M.choose_url(sound_config)
	if type(sound_config.url) == "table" then
		return sound_config.url[math.random(1, #sound_config.url)]
	end

	return sound_config.url
end


---@param sound_config audio.sound
---@param index number
---@return hash|string|url
function M.get_url_at_index(sound_config, index)
	local urls = sound_config.url
	if type(urls) == "table" then
		index = math.max(1, math.min(index, #urls))
		return urls[index]
	end

	return urls
end


---@param sound_config audio.sound
---@param callback fun(url: hash|string|url)
function M.for_each_url(sound_config, callback)
	local urls = sound_config.url
	if type(urls) == "table" then
		for _, url in ipairs(urls) do
			callback(url)
		end
		return
	end

	callback(urls)
end


---@param id string
---@return audio.sound|nil
function M.get_sound_config(id)
	return runtime.sounds[id]
end


---@param id string
---@param engine_gain number
function M.set_sound_gain_engine(id, engine_gain)
	local sound_config = M.get_sound_config(id)
	if not sound_config then
		return
	end

	M.for_each_url(sound_config, function(url)
		sound.set_gain(url, engine_gain)
	end)

	runtime.last_gains[id] = engine_gain
end


---@param dt number
function M.update_fades(dt)
	for id, fade in pairs(runtime.fades) do
		if dt >= fade.remaining then
			fade.value = fade.target
			runtime.fades[id] = nil
		else
			fade.value = fade.value + (fade.target - fade.value) * (dt / fade.remaining)
			fade.remaining = fade.remaining - dt
		end

		M.set_sound_gain_engine(id, fade.value)
	end
end


---@param id string
---@param delay number
---@param gain number|nil
---@return number handle
function M.schedule_delayed_play(id, delay, gain)
	local handle = runtime.next_delay_handle
	runtime.next_delay_handle = handle + 1
	runtime.delayed_plays[handle] = {
		id = id,
		remaining = delay,
		gain = gain,
	}
	return handle
end


---Cancel a delayed play by handle. Safe to call multiple times or with an unknown handle
---@param handle number|nil
function M.cancel_delayed_play(handle)
	if handle == nil then
		return
	end

	runtime.delayed_plays[handle] = nil
end


---@param url url|string|hash
function M.bind_host(url)
	runtime.host_url = url
end


---Clear the host if it matches the url. Called from `audio.script` final
---@param url url|string|hash|nil
function M.unbind_host(url)
	if url ~= nil and runtime.host_url ~= nil and tostring(runtime.host_url) ~= tostring(url) then
		return
	end

	runtime.host_url = nil
end


function M.has_host()
	return runtime.host_url ~= nil
end


---@param play table
function M.request_play(play)
	msg.post(runtime.host_url, MSG_PLAY, play)
end


---@param play table
function M.handle_play(play)
	if (runtime.playing_generation[play.id] or 0) ~= play.generation then
		return
	end

	runtime.props.gain = play.gain
	runtime.props.speed = play.speed
	local id = play.id
	local generation = play.generation
	sound.play(play.url, runtime.props, function()
		if (runtime.playing_generation[id] or 0) ~= generation then
			return
		end
		local current_instances = runtime.playing[id] or 0
		runtime.playing[id] = math.max(0, current_instances - 1)
	end)
end


---Resolve the url string to the full url in the current script context. It makes the sound url
---independent from the place it is played from, since the delayed plays and fades are processed
---in the audio host script
---@param url string|hash|url
---@return hash|string|url
local function resolve_url(url)
	if type(url) ~= "string" then
		return url
	end

	local is_resolved, resolved_url = pcall(msg.url, url)
	if not is_resolved then
		logger:warn("Can't resolve the sound url", url)
		return url
	end

	return resolved_url
end


---Make a copy of the sound config with the urls resolved in the current script context.
---The passed config is not modified, so the same sounds table can be registered several times
---@param sound_config audio.sound
---@return audio.sound
local function resolve_sound_config(sound_config)
	local config = {}
	for key, value in pairs(sound_config) do
		config[key] = value
	end

	local urls = sound_config.url
	if type(urls) == "table" then
		config.url = {}
		for index = 1, #urls do
			config.url[index] = resolve_url(urls[index])
		end
	else
		config.url = resolve_url(urls)
	end

	return config
end


---Register the sounds in addition to the already registered ones. The sounds with the same id are replaced
---@param sounds table<string, audio.sound>|nil
function M.add_sounds(sounds)
	if not sounds then
		return
	end

	for id, sound_config in pairs(sounds) do
		runtime.sounds[id] = resolve_sound_config(sound_config)
	end
end


---@param sounds table<string, audio.sound>|nil
function M.set_sounds(sounds)
	runtime.sounds = {}
	M.add_sounds(sounds)
end


---@return audio.internal.runtime
function M.get_runtime()
	return runtime
end


---@return number
function M.get_sounds_count()
	return M.count_table_entries(runtime.sounds)
end


---@param t table
---@return number
function M.count_table_entries(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end

	return count
end


---Clear the runtime data. The registered sounds and the audio host are kept.
---In-flight play messages are invalidated by bumping the generation of every registered sound
function M.reset_runtime()
	runtime.fades = {}
	runtime.delayed_plays = {}
	runtime.last_gains = {}
	runtime.last_play_time = {}
	runtime.playing = {}

	for id in pairs(runtime.sounds) do
		runtime.playing_generation[id] = (runtime.playing_generation[id] or 0) + 1
	end
end


return M
