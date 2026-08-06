---The sounds config for the audio module
---@type table<string, audio.sound>
return {
	click = {
		url = "/sounds#click",
	},
	coin = {
		url = { "/sounds#coin_1", "/sounds#coin_2", "/sounds#coin_3" },
		random_pitch = 0.1,
		max_instances = 3,
	},
	music = {
		url = "/sounds#music",
		play_cooldown = 0,
	},
}
