---@type table<string, audio.sound>
local SOUNDS = {
	click = {
		url = "/sounds#click",
	},
	coin = {
		url = { "/sounds#coin_1", "/sounds#coin_2", "/sounds#coin_3" },
		play_cooldown = 0,
		random_pitch = 0.1,
	},
	music = {
		url = "/sounds#music",
		play_cooldown = 0,
	},
	limited = {
		url = "/sounds#click",
		play_cooldown = 0,
		max_instances = 2,
	},
}


return function()
	describe("Defold Audio - Core Functionality", function()
		local audio ---@type audio
		local audio_internal ---@type audio.internal.api

		before(function()
			audio = require("audio.audio")
			audio_internal = require("audio.internal.audio_internal")
			audio.set_logger(nil)
			audio.reset_state()
			audio.init(SOUNDS)
		end)

		after(function()
			audio.reset_state()
		end)

		it("Should play the registered sound", function()
			audio.play("click")
			assert(audio.is_playing("click"))
		end)

		it("Should skip the unregistered sound", function()
			audio.play("unknown_sound")
			assert(not audio.is_playing("unknown_sound"))
		end)

		it("Should stop the playing sound", function()
			audio.play("music")
			assert(audio.is_playing("music"))

			audio.stop("music")
			assert(not audio.is_playing("music"))
		end)

		it("Should play the sound with the several urls", function()
			audio.play("coin")
			audio.play("coin")

			local runtime = audio_internal.get_runtime()
			assert(runtime.playing["coin"] == 2)
		end)

		it("Should play the sound with the url index", function()
			audio.play_index("coin", 2)
			assert(audio.is_playing("coin"))
		end)

		it("Should clamp the url index to the urls list", function()
			assert(audio_internal.get_url_at_index(SOUNDS.coin, 0) == "/sounds#coin_1")
			assert(audio_internal.get_url_at_index(SOUNDS.coin, 2) == "/sounds#coin_2")
			assert(audio_internal.get_url_at_index(SOUNDS.coin, 10) == "/sounds#coin_3")
			assert(audio_internal.get_url_at_index(SOUNDS.music, 10) == "/sounds#music")
		end)

		it("Should skip the play if the play cooldown is not passed", function()
			audio.play("click")
			audio.play("click")

			local runtime = audio_internal.get_runtime()
			assert(runtime.playing["click"] == 1)
		end)

		it("Should restart the sound if the max instances is reached", function()
			audio.play("limited")
			audio.play("limited")

			local runtime = audio_internal.get_runtime()
			assert(runtime.playing["limited"] == 2)

			audio.play("limited")
			assert(runtime.playing["limited"] == 1)
		end)

		it("Should clear the runtime data on reset state", function()
			audio.play("music")
			assert(audio.is_playing("music"))

			audio.reset_state()
			assert(not audio.is_playing("music"))
		end)

		it("Should keep the registered sounds on reset state", function()
			audio.reset_state()

			audio.play("music")
			assert(audio.is_playing("music"))
		end)
	end)
end
