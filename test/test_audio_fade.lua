---@type table<string, audio.sound>
local SOUNDS = {
	music = {
		url = "/sounds#music",
		play_cooldown = 0,
	},
	coin = {
		url = { "/sounds#coin_1", "/sounds#coin_2" },
		play_cooldown = 0,
	},
}


return function()
	describe("Defold Audio - Fade", function()
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

		it("Should set the gain instantly without the fade time", function()
			local runtime = audio_internal.get_runtime()

			audio.fade("music", 0)
			assert(runtime.last_gains["music"] == 0)
			assert(runtime.fades["music"] == nil)
		end)

		it("Should start the fade with the fade time", function()
			local runtime = audio_internal.get_runtime()

			audio.play("music", 1)
			audio.fade("music", 0, 1)

			local fade = runtime.fades["music"]
			assert(fade ~= nil)
			assert(fade.target == 0)
			assert(fade.value == audio_internal.to_engine_gain(1))
		end)

		it("Should change the gain on the fade update", function()
			local runtime = audio_internal.get_runtime()

			audio.play("music", 1)
			audio.fade("music", 0, 1)

			audio_internal.update_fades()
			assert(runtime.last_gains["music"] < 1)
			assert(runtime.last_gains["music"] > 0)
		end)

		it("Should finish the fade at the target gain", function()
			local runtime = audio_internal.get_runtime()

			audio.play("music", 1)
			audio.fade("music", 0, 1)

			-- The fade step is calculated for 60 updates per second
			for _ = 1, 120 do
				audio_internal.update_fades()
			end

			assert(runtime.last_gains["music"] == 0)
			assert(runtime.fades["music"] == nil)
			assert(runtime.fade_timer == nil)
		end)

		it("Should fade in the sound", function()
			local runtime = audio_internal.get_runtime()

			audio.play("music", 0)
			audio.fade("music", 1, 1)

			for _ = 1, 120 do
				audio_internal.update_fades()
			end

			assert(runtime.last_gains["music"] == audio_internal.to_engine_gain(1))
		end)

		it("Should stop the fade on the sound stop", function()
			local runtime = audio_internal.get_runtime()

			audio.play("music", 1)
			audio.fade("music", 0, 1)
			assert(runtime.fades["music"] ~= nil)

			audio.stop("music")
			assert(runtime.fades["music"] == nil)
		end)

		it("Should fade the sound with the several urls", function()
			local runtime = audio_internal.get_runtime()

			audio.play("coin", 1)
			audio.fade("coin", 0.5, 1)

			for _ = 1, 120 do
				audio_internal.update_fades()
			end

			assert(runtime.last_gains["coin"] == audio_internal.to_engine_gain(0.5))
		end)

		it("Should skip the fade for the unregistered sound", function()
			local runtime = audio_internal.get_runtime()

			audio.fade("unknown_sound", 0, 1)
			assert(runtime.fades["unknown_sound"] == nil)
		end)
	end)
end
