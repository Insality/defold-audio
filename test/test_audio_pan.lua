---@type table<string, audio.sound>
local SOUNDS = {
	buzz = {
		url = "/sounds#music",
		play_cooldown = 0,
	},
	coin = {
		url = { "/sounds#coin_1", "/sounds#coin_2" },
		play_cooldown = 0,
	},
}


return function()
	describe("Defold Audio - Pan", function()
		local audio ---@type audio
		local audio_internal ---@type audio.internal.api
		local runtime ---@type audio.internal.runtime
		local original_set_pan
		local original_play
		local original_post
		local pan_calls
		local play_calls
		local warnings

		before(function()
			audio = require("audio.audio")
			audio_internal = require("audio.internal.audio_internal")
			audio.reset_state()
			audio.add_sounds(SOUNDS)
			audio.init()
			runtime = audio_internal.get_runtime()

			warnings = 0
			audio.set_logger({
				trace = function() end,
				debug = function() end,
				info = function() end,
				warn = function() warnings = warnings + 1 end,
				error = function() end,
			})

			pan_calls = {}
			original_set_pan = sound.set_pan
			sound.set_pan = function(url, pan)
				table.insert(pan_calls, { url = url, pan = pan })
			end

			play_calls = {}
			original_play = sound.play
			sound.play = function(url, props)
				table.insert(play_calls, { url = url, pan = props.pan })
			end

			original_post = msg.post
			msg.post = function(url, message_id, message)
				if message_id == audio_internal.MSG_PLAY then
					audio_internal.handle_play(message)
					return
				end
				return original_post(url, message_id, message)
			end
		end)

		after(function()
			sound.set_pan = original_set_pan
			sound.play = original_play
			msg.post = original_post
			audio.set_logger(nil)
			audio.reset_state()
			audio.init()
		end)

		it("Should set the pan to the sound component", function()
			audio.set_pan("buzz", -0.5)

			assert(#pan_calls == 1)
			assert(pan_calls[1].url == audio_internal.get_sound_config("buzz").url)
			assert(pan_calls[1].pan == -0.5)
			assert(runtime.pans["buzz"] == -0.5)
		end)

		it("Should set the pan to all urls of the sound", function()
			audio.set_pan("coin", 0.5)

			assert(#pan_calls == 2)
			assert(pan_calls[1].pan == 0.5)
			assert(pan_calls[2].pan == 0.5)
		end)

		it("Should clamp the pan to the range", function()
			audio.set_pan("buzz", -2)
			assert(pan_calls[1].pan == -1)

			audio.set_pan("buzz", 2)
			assert(pan_calls[2].pan == 1)
		end)

		it("Should skip the engine call if the pan is not changed", function()
			audio.set_pan("buzz", 0.3)
			audio.set_pan("buzz", 0.3)
			audio.set_pan("buzz", 5)
			audio.set_pan("buzz", 1)

			assert(#pan_calls == 2)
		end)

		it("Should apply the first pan even if it's zero", function()
			audio.set_pan("buzz", 0)
			assert(#pan_calls == 1)
		end)

		it("Should keep the pan between the plays", function()
			audio.set_pan("buzz", -0.5)
			audio.play("buzz")
			audio.stop("buzz")
			audio.play("buzz")

			-- The component keeps the pan, the play pan is added to it, so it's not passed
			assert(#play_calls == 2)
			assert(play_calls[1].pan == nil)
			assert(play_calls[2].pan == nil)
			assert(#pan_calls == 1)
			assert(runtime.pans["buzz"] == -0.5)
		end)

		it("Should keep the pan during the fade", function()
			audio.play("buzz", 1)
			audio.fade("buzz", 0, 1)
			audio.set_pan("buzz", 0.5)
			audio.update(0.5)

			assert(#pan_calls == 1)
			assert(runtime.pans["buzz"] == 0.5)
		end)

		it("Should warn and skip the unregistered sound", function()
			audio.set_pan("unknown_sound", 0.5)

			assert(warnings == 1)
			assert(#pan_calls == 0)
			assert(runtime.pans["unknown_sound"] == nil)
		end)

		it("Should clear the pan on the reset state", function()
			audio.set_pan("buzz", 0.5)
			audio.reset_state()
			assert(runtime.pans["buzz"] == nil)

			audio.set_pan("buzz", 0.5)
			assert(#pan_calls == 2)
		end)

		it("Should clear the pan of the removed sounds", function()
			audio.set_pan("buzz", 0.5)
			audio.remove_sounds(SOUNDS)
			assert(runtime.pans["buzz"] == nil)
		end)
	end)
end
