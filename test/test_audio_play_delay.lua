---@type table<string, audio.sound>
local SOUNDS = {
	click = {
		url = "/sounds#click",
		play_cooldown = 0,
	},
	coin = {
		url = { "/sounds#coin_1", "/sounds#coin_2" },
		play_cooldown = 0,
	},
}


return function()
	describe("Defold Audio - Play Delay", function()
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

		it("Should schedule the delayed play and return a handle", function()
			local handle = audio.play_delay("click", 1)
			local runtime = audio_internal.get_runtime()

			assert(handle ~= nil)
			assert(runtime.delayed_plays[handle] ~= nil)
			assert(not audio.is_playing("click"))
		end)

		it("Should play the sound when the remaining counter reaches zero", function()
			local handle = audio.play_delay("click", 2 / 60)
			local runtime = audio_internal.get_runtime()

			audio.update()
			assert(runtime.delayed_plays[handle] ~= nil)
			assert(not audio.is_playing("click"))

			audio.update()
			assert(runtime.delayed_plays[handle] == nil)
			assert(audio.is_playing("click"))
		end)

		it("Should cancel the delayed play by handle", function()
			local handle = audio.play_delay("click", 1)
			audio.cancel_play_delay(handle)

			local runtime = audio_internal.get_runtime()
			assert(runtime.delayed_plays[handle] == nil)

			for _ = 1, 120 do
				audio.update()
			end

			assert(not audio.is_playing("click"))
		end)

		it("Should cancel the delayed play idempotently", function()
			local handle = audio.play_delay("click", 1)

			audio.cancel_play_delay(handle)
			audio.cancel_play_delay(handle)
			audio.cancel_play_delay(nil)
			audio.cancel_play_delay(99999)

			local runtime = audio_internal.get_runtime()
			assert(runtime.delayed_plays[handle] == nil)
			assert(not audio.is_playing("click"))
		end)

		it("Should play immediately when the delay is zero or negative", function()
			local handle = audio.play_delay("click", 0)
			local runtime = audio_internal.get_runtime()

			assert(handle == nil)
			assert(next(runtime.delayed_plays) == nil)
			assert(audio.is_playing("click"))
		end)

		it("Should skip the unregistered sound", function()
			local handle = audio.play_delay("unknown_sound", 1)
			assert(handle == nil)
		end)

		it("Should clear the delayed plays on reset state", function()
			local handle = audio.play_delay("click", 1)
			audio.reset_state()

			local runtime = audio_internal.get_runtime()
			assert(runtime.delayed_plays[handle] == nil)
		end)

		it("Should keep several delayed plays independent", function()
			local click_handle = audio.play_delay("click", 1 / 60)
			local coin_handle = audio.play_delay("coin", 3 / 60)

			audio.update()
			assert(audio.is_playing("click"))
			assert(not audio.is_playing("coin"))

			audio.cancel_play_delay(coin_handle)
			audio.update()
			audio.update()

			assert(not audio.is_playing("coin"))
			assert(click_handle ~= coin_handle)
		end)
	end)
end
