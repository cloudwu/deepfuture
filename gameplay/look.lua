local flow = require "core.flow"
local card = require "gameplay.card"
local vtips = require "visual.tips".layer "hud"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local mouse = require "core.mouse"

global pairs, print, print_r

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

local function wait_click(p, focus_state)
	local desc = { n = nil }
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" and p[focus_state.object] then
				desc.n = p[focus_state.object]
				vtips.set ("tips.look.focus", desc)
			elseif focus_state.object then
				vtips.set()
			else
				vtips.set()
			end
		end
		if mouse.click(focus_state, "left") or mouse.click(focus_state, "right") then
			return
		end
		flow.sleep(0)
	end
end

function M.start(seen, focus_state)
	local pile = look(seen)
	wait_click(pile, focus_state)
	vtips.set()
	return_deck(pile)
end

return M