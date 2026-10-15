---@type table<string, audio.sound>
local SOUNDS = {
	buzz = {
		url = "/sounds#music",
		play_cooldown = 0,
		fade_in = 0.2,
		fade_out = 0.2,
	},
	music = {
		url = "/sounds#music",
		play_cooldown = 0,
	},
}


return function()
	describe("Defold Audio - Fade In, Fade Out and Set Playing", function()
		local audio ---@type audio
		local audio_internal ---@type audio.internal.api
		local runtime ---@type audio.internal.runtime

		before(function()
			audio = require("audio.audio")
			audio_internal = require("audio.internal.audio_internal")
			audio.set_logger(nil)
			audio.reset_state()
			audio.add_sounds(SOUNDS)
			audio.init()
			runtime = audio_internal.get_runtime()
		end)

		after(function()
			audio.reset_state()
		end)

		it("Should fade in the sound with the fade_in config", function()
			audio.play("buzz", 0.6)
			assert(runtime.last_gains["buzz"] == 0)
			assert(runtime.fades["buzz"].target == 0.6)

			audio.update(0.2)
			assert(runtime.last_gains["buzz"] == 0.6)
			assert(runtime.fades["buzz"] == nil)
		end)

		it("Should play the sound without the fade_in config instantly", function()
			audio.play("music", 0.6)
			assert(runtime.last_gains["music"] == 0.6)
			assert(runtime.fades["music"] == nil)
		end)

		it("Should stop the sound instantly without the fade out", function()
			audio.play("music")
			audio.stop("music")
			assert(not audio.is_playing("music"))
		end)

		it("Should fade out and stop the sound with the fade out time", function()
			audio.play("music", 0.8)
			audio.stop("music", 1)
			assert(audio.is_playing("music"))

			audio.update(0.5)
			assert(audio.is_playing("music"))
			assert(math.abs(runtime.last_gains["music"] - 0.4) < 0.0001)

			audio.update(0.5)
			assert(not audio.is_playing("music"))
			assert(runtime.fades["music"] == nil)
		end)

		it("Should keep the gain after the fade out stop", function()
			audio.play("music", 0.8)
			audio.stop("music", 1)
			audio.update(1)

			assert(runtime.last_gains["music"] == 0.8)
		end)

		it("Should keep the gain after the instant stop during the fade out", function()
			audio.play("music", 0.8)
			audio.stop("music", 1)
			audio.update(0.5)
			audio.stop("music", 0)

			assert(not audio.is_playing("music"))
			assert(runtime.last_gains["music"] == 0.8)
		end)

		it("Should use the fade_out config on the stop", function()
			audio.play("buzz")
			audio.update(0.2)
			audio.stop("buzz")
			assert(audio.is_playing("buzz"))

			audio.update(0.2)
			assert(not audio.is_playing("buzz"))
		end)

		it("Should not restart the fade out on the repeated stop", function()
			audio.play("music", 1)
			audio.stop("music", 1)
			audio.update(0.5)
			audio.stop("music", 1)

			assert(runtime.fades["music"].remaining == 0.5)
		end)

		it("Should cancel the stop on the fade during the fade out", function()
			audio.play("music", 1)
			audio.stop("music", 1)
			audio.fade("music", 1, 1)
			audio.update(1)

			assert(audio.is_playing("music"))
			assert(runtime.last_gains["music"] == 1)
		end)

		it("Should cancel the stop on the play during the fade out", function()
			audio.play("music", 1)
			audio.stop("music", 1)
			audio.update(0.5)
			audio.play("music")
			audio.update(1)

			assert(audio.is_playing("music"))
			assert(runtime.last_gains["music"] == 1)
		end)

		it("Should fade in from the current gain on the play during the fade out", function()
			audio.play("buzz", 0.6)
			audio.update(0.2)
			audio.stop("buzz")
			audio.update(0.1)

			local gain = runtime.last_gains["buzz"]
			audio.play("buzz")
			assert(runtime.last_gains["buzz"] == gain)

			audio.update(0.2)
			assert(audio.is_playing("buzz"))
			assert(runtime.last_gains["buzz"] == 0.6)
		end)

		it("Should fade in the sound on set playing", function()
			audio.set_playing("buzz", true)
			assert(audio.is_playing("buzz"))
			assert(runtime.last_gains["buzz"] == 0)

			audio.update(0.2)
			assert(runtime.last_gains["buzz"] == 1)
		end)

		it("Should not restart the sound on the same set playing state", function()
			audio.set_playing("buzz", true)
			audio.update(0.1)
			audio.set_playing("buzz", true)

			assert(runtime.playing["buzz"] == 1)
			assert(runtime.fades["buzz"].remaining == 0.1)
		end)

		it("Should fade out and stop the sound on set playing false", function()
			audio.set_playing("buzz", true)
			audio.update(0.2)
			audio.set_playing("buzz", false)
			assert(audio.is_playing("buzz"))

			audio.update(0.2)
			assert(not audio.is_playing("buzz"))
			assert(runtime.last_gains["buzz"] == 1)
		end)

		it("Should turn the fade around without the sound restart", function()
			audio.set_playing("buzz", true)
			audio.update(0.2)
			audio.set_playing("buzz", false)
			audio.update(0.1)

			local gain = runtime.last_gains["buzz"]
			assert(gain > 0 and gain < 1)

			audio.set_playing("buzz", true)
			assert(runtime.playing["buzz"] == 1)
			assert(runtime.last_gains["buzz"] == gain)

			audio.update(0.2)
			assert(audio.is_playing("buzz"))
			assert(runtime.last_gains["buzz"] == 1)
		end)

		it("Should turn the fade in around to the fade out", function()
			audio.set_playing("buzz", true)
			audio.update(0.1)
			audio.set_playing("buzz", false)
			audio.update(0.2)

			assert(not audio.is_playing("buzz"))
			assert(runtime.last_gains["buzz"] == 1)
		end)

		it("Should fade to the sound gain on set playing", function()
			audio.play("buzz", 0.5)
			audio.update(0.2)
			audio.set_playing("buzz", false)
			audio.update(0.2)

			audio.set_playing("buzz", true)
			audio.update(0.2)
			assert(runtime.last_gains["buzz"] == 0.5)
		end)

		it("Should use the fade time of set playing", function()
			audio.set_playing("music", true, 1)
			audio.update(0.5)
			assert(runtime.last_gains["music"] == 0.5)

			audio.set_playing("music", false, 1)
			audio.update(1)
			assert(not audio.is_playing("music"))
		end)

		it("Should play and stop instantly on set playing without the fade time", function()
			audio.set_playing("music", true)
			assert(runtime.last_gains["music"] == 1)

			audio.set_playing("music", false)
			assert(not audio.is_playing("music"))
		end)

		it("Should stop the fading out sound on the remove", function()
			audio.set_playing("buzz", true)
			audio.update(0.2)
			audio.set_playing("buzz", false)
			audio.remove_sounds(SOUNDS)

			assert(not audio.is_playing("buzz"))
		end)

		it("Should skip set playing for the unregistered sound", function()
			audio.set_playing("unknown_sound", true)
			assert(not audio.is_playing("unknown_sound"))
		end)
	end)
end
