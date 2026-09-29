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
		local original_set_gain
		local original_post
		local play_calls
		local engine_calls

		before(function()
			audio = require("audio.audio")
			audio_internal = require("audio.internal.audio_internal")
			audio.set_logger(nil)
			audio.reset_state()
			audio.add_sounds(SOUNDS)
			audio.init()

			play_calls = {}
			engine_calls = {}
			original_play = sound.play
			sound.play = function(url, props, callback)
				table.insert(play_calls, { url = url, speed = props.speed, callback = callback })
				table.insert(engine_calls, { name = "play", url = url })
			end

			original_set_gain = sound.set_gain
			sound.set_gain = function(url, gain)
				table.insert(engine_calls, { name = "set_gain", url = url, gain = gain })
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
			sound.set_gain = original_set_gain
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

		it("Should set the gain after the sound play to keep the editor gain", function()
			audio.play("click", 1)
			audio.play("click", 0.5)

			assert(#engine_calls == 4)
			assert(engine_calls[1].name == "play")
			assert(engine_calls[2].name == "set_gain" and engine_calls[2].gain == 1)
			assert(engine_calls[3].name == "play")
			assert(engine_calls[4].name == "set_gain" and engine_calls[4].gain == 0.5)
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
