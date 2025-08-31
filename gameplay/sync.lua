local card = require "gameplay.card"
local vdesktop = require "visual.desktop"
local flow = require "core.flow"
local track = require "gameplay.track"
local map = require "gameplay.map"

global ipairs

local function get_pile(what)
	local i = 1
	local p = {}
	repeat
		local c = card.card(what, i)
		p[i] = c
		i = i + 1
	until not c
	return p
end

local function sync(where)
	local p = get_pile(where)
	local diff = vdesktop.sync(where, p)
	if not diff then
		return
	end
	for _, c in ipairs(diff.discard) do
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
	for _, c in ipairs(diff.draw) do
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, where)
		flow.sleep(5)
	end
end

return function()
	sync "hand"
	sync "homeworld"
	sync "colony"
	sync "neutral"
	track.sync()
	map.sync()
end
