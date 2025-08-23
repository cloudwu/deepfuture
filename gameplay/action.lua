local card = require "gameplay.card"
local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips".layer "hud"
local map = require "gameplay.map"
local show_desc = require "gameplay.desc"
local rules = require "core.rules".phase

local function choose_action()
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
			elseif where ~= "discard" and focus_state.object then
				vtips.set("tips." .. where)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c, where = focus.click "right"
		if c and where ~= "discard" then
			vtips.set()
			show_desc {
				region = where,
				card = c,
			}
		end
		flow.sleep(0)
	end
end

local check = {}

-- check settle
function check.M(hands)
	
end

-- check grow
function check.R(hands)
end

local function check_action(hands)
	local disable = {}
	for suit, f in pairs(check) do
		disable[suit] = f(hands)
	end
	return disable
end

return function ()
	local disable = check_action(hands)

	vdesktop.set_text("phase", "$(phase.action)")
	choose_action()
	return "idle"
end
