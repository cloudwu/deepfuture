local flow = require "core.flow"
local card = require "gameplay.card"
local vtips = require "visual.tips".layer "hud"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local focus = require "core.focus"

global pairs, print

local M = {}

local function look(seen)
	local r = {}
	for i = 1, seen do
		local c = card.card("draw", i)
		r[c] = i
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "float")
		vcard.mask(c, true)
		flow.sleep(5)
	end
	return r
end

local function return_deck(p)
	for c in pairs(p) do
		vdesktop.transfer("float", c, "deck")
		vcard.mask(c)
		flow.sleep(0)
	end
end

local function wait_click(p)
	local focus_state = {}
	local desc = { n = nil }
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "float" and p[focus_state.object] then
				desc.n = p[focus_state.object]
				vtips.set ("tips.look.focus", desc)
			else
				vtips.set()
			end
		elseif focus_state.lost then
			vtips.set()
		end
		if focus.click "left" or focus.click "right" then
			return
		end
		flow.sleep(0)
	end
end

function M.start(seen)
	local pile = look(seen)
	wait_click(pile)
	vtips.set()
	return_deck(pile)
end

return M