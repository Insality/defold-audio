---@type table<string, audio.sound>
local SOUNDS = {
	click = {
		url = "/sounds#click",
		play_cooldown = 0,
	},
	coin = {
		url = { "/sounds#coin_1", "/sounds#coin_2" },
		play_cooldown = 0,
		random_pitch = 0.1,
		max_instances = 2,
	},
}


---Get the socket name of the url, to build the full url string inside the test collection
---@param url url
---@return string
local function get_socket_name(url)
	return string.match(tostring(url), "%[(.-):") or ""
end


return function()
	describe("Defold Audio - Sound Urls", function()
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

		it("Should resolve the relative url to the full url on init", function()
			local sound_config = audio_internal.get_sound_config("click")
			assert(sound_config.url == msg.url("/sounds#click"))
		end)

		it("Should resolve every url in the urls list", function()
			local sound_config = audio_internal.get_sound_config("coin")
			assert(sound_config.url[1] == msg.url("/sounds#coin_1"))
			assert(sound_config.url[2] == msg.url("/sounds#coin_2"))
		end)

		it("Should keep the passed sounds config unchanged", function()
			assert(SOUNDS.click.url == "/sounds#click")
			assert(SOUNDS.coin.url[1] == "/sounds#coin_1")
			assert(SOUNDS.coin.url[2] == "/sounds#coin_2")
		end)

		it("Should keep the other sound config fields", function()
			local sound_config = audio_internal.get_sound_config("coin")
			assert(sound_config.play_cooldown == 0)
			assert(sound_config.random_pitch == 0.1)
			assert(sound_config.max_instances == 2)
		end)

		it("Should keep the full url with the socket the same", function()
			local socket_name = get_socket_name(msg.url("/sounds#click"))
			audio.init({
				click = { url = socket_name .. ":/sounds#click" },
			})

			local sound_config = audio_internal.get_sound_config("click")
			assert(sound_config.url == msg.url("/sounds#click"))
		end)

		it("Should keep the already resolved url as is", function()
			local resolved_url = msg.url("/sounds#click")
			audio.init({
				click = { url = resolved_url },
			})

			local sound_config = audio_internal.get_sound_config("click")
			assert(sound_config.url == resolved_url)
		end)

		it("Should resolve the same sounds config on the repeated init", function()
			audio.init(SOUNDS)
			audio.init(SOUNDS)

			local sound_config = audio_internal.get_sound_config("click")
			assert(sound_config.url == msg.url("/sounds#click"))
		end)

		it("Should keep the sound registered if the url can't be resolved", function()
			audio.init({
				broken = { url = "bad:url:with#too#many" },
			})

			assert(audio_internal.get_sound_config("broken") ~= nil)
		end)

		it("Should register the additional sounds with add_sounds", function()
			audio.add_sounds({
				music = { url = "/sounds#music", play_cooldown = 0 },
			})

			local sound_config = audio_internal.get_sound_config("music")
			assert(sound_config.url == msg.url("/sounds#music"))
			assert(audio_internal.get_sound_config("click") ~= nil)

			audio.play("music")
			assert(audio.is_playing("music"))
		end)

		it("Should replace the sound with the same id on add_sounds", function()
			audio.add_sounds({
				click = { url = "/sounds#music", play_cooldown = 0 },
			})

			local sound_config = audio_internal.get_sound_config("click")
			assert(sound_config.url == msg.url("/sounds#music"))
			assert(audio_internal.get_sounds_count() == 2)
		end)
	end)
end
