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
	describe("Defold Audio - Play Host", function()
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
			audio.add_sounds(SOUNDS)
			audio.init()

			play_calls = {}
			original_play = sound.play
			sound.play = function(url, props, callback)
				table.insert(play_calls, { url = url, gain = props.gain, speed = props.speed, callback = callback })
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
			audio.init()
		end)

		it("Should start the sound through the audio host", function()
			audio.play("click")
			assert(#play_calls == 1)
			assert(audio.is_playing("click"))
		end)

		it("Should start the sound with the registered url", function()
			audio.play("click")

			assert(#play_calls == 1)
			assert(play_calls[1].url == audio_internal.get_sound_config("click").url)
			assert(play_calls[1].callback ~= nil)
		end)

		it("Should keep the gain of every play", function()
			audio.play("click", 1)
			audio.play("click", 0.5)

			assert(#play_calls == 2)
			assert(play_calls[1].gain == 1)
			assert(play_calls[2].gain == 0.25)
		end)

		it("Should start several sounds on the host", function()
			audio.play("coin")
			audio.play("coin")

			assert(#play_calls == 2)
		end)

		it("Should skip the play if the audio host is missing", function()
			audio_internal.unbind_host()

			audio.play("click")
			assert(#play_calls == 0)
			assert(not audio.is_playing("click"))
		end)

		it("Should skip the play if the sound is stopped before the host handles it", function()
			msg.post = function()
				-- Keep the play queued in the message and handle it later
			end

			audio.play("click")
			assert(audio.is_playing("click"))

			audio.stop("click")
			audio_internal.handle_play({
				id = "click",
				url = audio_internal.get_sound_config("click").url,
				gain = 1,
				speed = 1,
				generation = 0,
			})

			assert(#play_calls == 0)
			assert(not audio.is_playing("click"))
		end)

		it("Should skip the queued play after the reset state", function()
			msg.post = function()
				-- Keep the play queued in the message and handle it later
			end

			audio.play("click")
			assert(audio.is_playing("click"))

			local play = {
				id = "click",
				url = audio_internal.get_sound_config("click").url,
				gain = 1,
				speed = 1,
				generation = 0,
			}

			audio.reset_state()
			audio_internal.handle_play(play)

			assert(#play_calls == 0)
			assert(not audio.is_playing("click"))
		end)

		it("Should keep the audio host on the reset state", function()
			audio.reset_state()
			audio.play("click")

			assert(#play_calls == 1)
			assert(audio.is_playing("click"))
		end)

		it("Should start the delayed sound on the tick it expires", function()
			audio.play_delay("click", 1 / 60)

			audio.update(1 / 60)
			assert(#play_calls == 1)
			assert(audio.is_playing("click"))
		end)
	end)
end
