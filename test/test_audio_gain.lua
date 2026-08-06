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


return function()
	describe("Defold Audio - Gain and State", function()
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

		it("Should return the default group gain", function()
			assert(audio.get_gain("music") == 1)
			assert(audio.get_gain("unknown_group") == 1)
		end)

		it("Should set the group gain", function()
			audio.set_gain("music", 0.5)
			assert(audio.get_gain("music") == 0.5)

			audio.set_gain("sfx", 0.2)
			assert(audio.get_gain("sfx") == 0.2)
			assert(audio.get_gain("music") == 0.5)
		end)

		it("Should clamp the group gain to [0 .. 1]", function()
			audio.set_gain("music", 2)
			assert(audio.get_gain("music") == 1)

			audio.set_gain("music", -1)
			assert(audio.get_gain("music") == 0)

			audio.set_gain("music", nil)
			assert(audio.get_gain("music") == 1)
		end)

		it("Should convert the linear gain to the engine gain", function()
			assert(audio_internal.to_engine_gain(1) == 1)
			assert(audio_internal.to_engine_gain(0) == 0)
			assert(audio_internal.to_engine_gain(0.5) == 0.25)
		end)

		it("Should keep the group gains in the state", function()
			audio.set_gain("music", 0.3)
			audio.set_gain("sfx", 0.7)

			local state = audio.get_state()
			assert(state.groups["music"] == 0.3)
			assert(state.groups["sfx"] == 0.7)
		end)

		it("Should restore the group gains from the state", function()
			audio.set_state({ groups = { music = 0.4, sfx = 0.6 } })
			audio.init(SOUNDS)

			assert(audio.get_gain("music") == 0.4)
			assert(audio.get_gain("sfx") == 0.6)
		end)

		it("Should reset the group gains on reset state", function()
			audio.set_gain("music", 0.3)
			audio.reset_state()

			assert(audio.get_gain("music") == 1)
			assert(next(audio.get_state().groups) == nil)
		end)

		it("Should keep the last sound gain between the plays", function()
			local runtime = audio_internal.get_runtime()

			audio.play("click", 0.5)
			assert(runtime.last_gains["click"] == audio_internal.to_engine_gain(0.5))

			audio.play("click")
			assert(runtime.last_gains["click"] == audio_internal.to_engine_gain(0.5))

			audio.play("click", 1)
			assert(runtime.last_gains["click"] == audio_internal.to_engine_gain(1))
		end)

		it("Should clamp the sound gain to [0 .. 1]", function()
			local runtime = audio_internal.get_runtime()

			audio.play("click", 5)
			assert(runtime.last_gains["click"] == audio_internal.to_engine_gain(1))

			audio.play("click", -5)
			assert(runtime.last_gains["click"] == audio_internal.to_engine_gain(0))
		end)
	end)
end
