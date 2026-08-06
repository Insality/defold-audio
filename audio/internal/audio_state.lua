---The audio module state, can be saved and loaded between game sessions
---@class audio.state
---@field groups table<string, number> The linear gain of the sound groups by group name

local M = {}
M.DEFAULT_GAIN = 1

---@type audio.state
local state = {
	groups = {},
}


function M.reset()
	state = {
		groups = {},
	}
end


---@return audio.state
function M.get_state()
	return state
end


---@param new_state audio.state
function M.set_state(new_state)
	state = new_state
end


---@param group string
---@return number
function M.get_group_gain(group)
	return state.groups[group] or M.DEFAULT_GAIN
end


---@param group string
---@param value number
function M.set_group_gain(group, value)
	state.groups[group] = value
end


return M
