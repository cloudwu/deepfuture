local card = require "gameplay.card"
local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips"
local map = require "gameplay.map"

return function ()
	local desc = {
		action = nil,
		desc = nil,
	}

	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			local where = focus_state.active
			local c = focus_state.object
			if where == "hand" then
				desc.action = "$(action." .. c.suit .. ")"
				if c.suit == "H" and map.is_safe() then
					desc.desc = "$(action." .. c.suit .. ".desc.safe)"
				else
					desc.desc = "$(action." .. c.suit .. ".desc)"
				end
				vtips.set("tips.action.choose", desc)
			elseif focus_state.object then
				vtips.set("tips." .. where)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c = focus.click "right"
		if c then
			local args = {
				region = where,
				card = c,
			}
			vtips.set()
			flow.enter("desc", args)
		end
		flow.sleep(0)
	end
	return "idle"
end
