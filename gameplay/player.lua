local card = require "gameplay.card"
local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips"

local function sleep()
	flow.sleep(5)
end

local function draw_hands()
	for i = 1, 5 do
		local c = card.draw_hand()
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		sleep()
	end
end

local function choose_action()
	local ux = {}
	local desc = {
		action = nil,
	}
	function ux.hand(_, c)
		if not c then
			vtips.set()
			return
		end
		
		desc.action = "$(action." .. c.suit .. ")"
		vtips.set("tips.action.choose", desc)
	end
	
	while true do
		focus.dispatch(ux)
		flow.sleep(0)
	end
end

local persist = require "gameplay.persist"

return function ()
	draw_hands()
--	persist.save "game.txt"
	choose_action()
	return "idle"
end
