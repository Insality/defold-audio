local audio_state = require("audio.internal.audio_state")

local FADE_DT = 1 / 60

---@class audio.internal.fade
---@field id string
---@field value number
---@field target number
---@field step number

---The sound config, used to register the sound in the audio module
---@class audio.sound
---@field url string|string[] The sound component url or the list of urls to pick a random one
---@field random_pitch number|nil The random pitch in range [0 .. 1]. The sound speed will be randomized in range [1 - random_pitch .. 1 + random_pitch]
---@field play_cooldown number|nil The minimum time in seconds between the sound plays. Default is 4/60. Set 0 to disable
---@field max_instances number|nil The maximum number of simultaneously playing instances. The oldest instances are stopped on overflow

---@class audio.internal.runtime
---@field sounds table<string, audio.sound>
---@field fades table<string, audio.internal.fade>
---@field fade_timer number|nil
---@field last_gains table<string, number>
---@field last_play_time table<string, number>
---@field playing table<string, number>
---@field playing_generation table<string, number>
---@field props table<string, number>

---@class audio.internal.api
local M = {}

---@type audio.internal.runtime
local runtime = {
	sounds = {},
	fades = {},
	fade_timer = nil,
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


---@param id string
---@return audio.sound|nil
function M.get_sound_config(id)
	return runtime.sounds[id]
end


function M.stop_fade_timer()
	if runtime.fade_timer then
		timer.cancel(runtime.fade_timer)
		runtime.fade_timer = nil
	end
end


---@param id string
---@param engine_gain number
function M.set_sound_gain_engine(id, engine_gain)
	local sound_config = M.get_sound_config(id)
	if not sound_config then
		return
	end

	local urls = sound_config.url
	if type(urls) == "table" then
		for _, url in ipairs(urls) do
			sound.set_gain(url, engine_gain)
		end
	else
		sound.set_gain(urls, engine_gain)
	end

	runtime.last_gains[id] = engine_gain
end


function M.update_fades()
	local has_fades = false

	for id, fade in pairs(runtime.fades) do
		has_fades = true

		if fade.value < fade.target then
			fade.value = math.min(fade.target, fade.value + fade.step)
		elseif fade.value > fade.target then
			fade.value = math.max(fade.target, fade.value - fade.step)
		end

		M.set_sound_gain_engine(id, fade.value)

		if fade.value == fade.target then
			runtime.fades[id] = nil
		end
	end

	if not has_fades or next(runtime.fades) == nil then
		M.stop_fade_timer()
	end
end


function M.on_fade_tick()
	M.update_fades()
end


function M.ensure_fade_timer()
	if runtime.fade_timer then
		return
	end

	runtime.fade_timer = timer.delay(FADE_DT, true, M.on_fade_tick)
end


---@param sounds table<string, audio.sound>|nil
function M.set_sounds(sounds)
	runtime.sounds = sounds or {}
end


---@return audio.internal.runtime
function M.get_runtime()
	return runtime
end


---@return number
function M.get_fade_dt()
	return FADE_DT
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


function M.reset_runtime()
	runtime.fades = {}
	runtime.last_gains = {}
	runtime.last_play_time = {}
	runtime.playing = {}
	runtime.playing_generation = {}
	M.stop_fade_timer()
end


return M
