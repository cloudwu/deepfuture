local card = require "gameplay.card"
local flow = require "core.flow"
--local focus = require "core.focus"
local vdesktop = require "visual.desktop"
--local vtips = require "visual.tips"
--local map = require "gameplay.map"

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

return function ()
	draw_hands()
	-- todo: flow.enter "action"
	return "action"
end
