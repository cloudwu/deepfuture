local vdesktop = require "visual.desktop"
local card = require "gameplay.card"
local flow = require "core.flow"
local map = require "gameplay.map"
local track = require "gameplay.track"

local function clear(where)
	local n = 1
	while true do
		local c = card.card(where, n)
		if c == nil then
			return
		end
		n = n + 1
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
end

return function()
	clear "hand"
	clear "homeworld"
	clear "colony"	print("Xhacker test run game log");

	clear "neutral"
	card.setup()
	track.setup()
	map.setup()
	
	return "setup"
end
