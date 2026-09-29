---@type table<string, audio.sound>
local SOUNDS = {
	click = {
		url = "/sounds#click",
		play_cooldown = 0,
	},
	music = {
		url = "/sounds#music",
		play_cooldown = 0,
	},
}

---@type table<string, audio.sound>
local WINDOW_SOUNDS = {
	coin = {
		url = { "/sounds#coin_1", "/sounds#coin_2" },
		play_cooldown = 0,
	},
}


return function()
	describe("Defold Audio - Remove Sounds", function()
		local audio ---@type audio
		local audio_internal ---@type audio.internal.api
		local original_play
		local original_post
		local play_calls

		before(function()
			audio = require("audio.audio")
			audio_internal = require("audio.internal.audio_internal")
			audio.set_logger(nil)
			audio.reset_state()
			audio_internal.set_sounds(SOUNDS)
			audio.add_sounds(WINDOW_SOUNDS)
			audio.init()

			play_calls = {}
			original_play = sound.play
			sound.play = function(url)
				table.insert(play_calls, url)
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
			sound.play = original_play
			msg.post = original_post
			audio.reset_state()
		end)

		it("Should unregister the removed sounds", function()
			audio.remove_sounds(WINDOW_SOUNDS)

			assert(audio_internal.get_sound_config("coin") == nil)
			audio.play("coin")
			assert(#play_calls == 0)
			assert(not audio.is_playing("coin"))
		end)

		it("Should keep the other sounds", function()
			audio.remove_sounds(WINDOW_SOUNDS)

			assert(audio_internal.get_sound_config("click") ~= nil)
			audio.play("click")
			assert(#play_calls == 1)
		end)

		it("Should skip the nil sounds", function()
			audio.remove_sounds(nil)
			assert(audio_internal.get_sound_config("coin") ~= nil)
		end)

		it("Should cancel the delayed plays of the removed sounds", function()
			audio.play_delay("coin", 0.5)
			audio.play_delay("click", 0.5)

			audio.remove_sounds(WINDOW_SOUNDS)
			audio.update(1)

			assert(#play_calls == 1)
			assert(audio.is_playing("click"))
			assert(not audio.is_playing("coin"))
		end)

		it("Should cancel the fades of the removed sounds", function()
			local runtime = audio_internal.get_runtime()

			audio.play("coin", 1)
			audio.fade("coin", 0, 1)
			assert(runtime.fades["coin"] ~= nil)

			audio.remove_sounds(WINDOW_SOUNDS)
			assert(runtime.fades["coin"] == nil)
			assert(runtime.last_gains["coin"] == nil)
		end)

		it("Should skip the queued play of the removed sound", function()
			msg.post = function()
				-- Keep the play queued in the message and handle it later
			end

			audio.play("coin")
			assert(audio.is_playing("coin"))

			local play = {
				id = "coin",
				url = audio_internal.get_sound_config("coin").url[1],
				gain = 1,
				speed = 1,
				generation = 0,
			}

			audio.remove_sounds(WINDOW_SOUNDS)
			audio_internal.handle_play(play)

			assert(#play_calls == 0)
			assert(not audio.is_playing("coin"))
		end)

		it("Should play the sound after it's added again", function()
			audio.remove_sounds(WINDOW_SOUNDS)
			audio.add_sounds(WINDOW_SOUNDS)

			audio.play("coin")
			assert(#play_calls == 1)
			assert(audio.is_playing("coin"))
		end)
	end)
end
