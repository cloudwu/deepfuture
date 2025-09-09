local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local mouse = require "core.mouse"
local card = require "gameplay.card"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"
local victory = require "gameplay.victory"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vmap = require "visual.map"
local color = require "visual.color"
local vcard = require "visual.card"
local rules_vic = require "core.rules".victory
local ui = require "core.rules".ui
local table = table

global print, pairs, next, ipairs

local COLOR <const> = color.blend(0x01000000, ui.card.mask_focus)
local DURATION <const> = ui.focus.duration

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

local function check_tech()
	local mask = {}
	local function focus_card(c)
		mask[c] = 0
	end
	local function focus_update()
		for c, duration in pairs(mask) do
			local f = duration + 1
			if f >= DURATION * 2 then
				f = 0
				mask[c] = nil
			else
				mask[c] = f
			end
			if f >= DURATION then
				f = DURATION * 2 - 1 - f 
			end
			if f == 0 then
				vcard.mask(c)
			else
				f = f + 1
				vcard.mask(c, COLOR(f))
			end
		end
	end
	
	local n = 1
	while true do
		local c = card.card("homeworld", n)
		if c == nil then
			break
		end
		n = n + 1
		if card.complete(c) then
			focus_card(c)
			for i = 1, 5 do
				focus_update()
				flow.sleep(0)
			end
		end
	end
	while next(mask) do
		focus_update()
		flow.sleep(0)
	end
end

local function gen_extra(vics)
	local tmp = {}
	for _, vic in ipairs(vics) do
		tmp[#tmp+1] = "${vic." .. vic .. "|}"
	end
	return table.concat(tmp, " ")
end

local victory_ani = {}
local PLAYER <const> = ui.map.player

function victory_ani.population(checker, extra)
	local pop = extra.vic
	local count = 0
	for sec, n in pairs(checker) do
		for i = 1, n do
			count = count + 1
			pop.people = count	
			vmap.set(sec, PLAYER, n, i)
			vmap.update()
			vdesktop.set_text("phase", extra)
			flow.sleep(1)
		end
	end
end

function victory_ani.territory(checker, extra)
	local t = extra.vic
	local count = 0
	for sec in pairs(checker) do
		count = count + 1
		t.sec = count
		vmap.focus(sec)
		vdesktop.set_text("phase", extra)
		flow.sleep(5)
	end
end

function victory_ani.culture(checker, extra)
	track.focus("C", true)
	flow.sleep(30)
	track.focus(nil)
end

function victory_ani.might(checker, extra)
	track.focus("M", true)
	flow.sleep(30)
	track.focus(nil)
end

function victory_ani.stability(checker, extra)
	track.focus("S", true)
	flow.sleep(30)
	track.focus(nil)
end

function victory_ani.xeno(checker, extra)
	track.focus("X", true)
	flow.sleep(30)
	track.focus(nil)
end

return function()
	vdesktop.set_text("phase", {
		text = "$(phase.victory)",
	})
	check_tech()
	
	local vics = {}
	local checker = victory.checker()
	for _, vic in ipairs(rules_vic.name) do
		if checker[vic](checker) then
			vics[#vics+1] = vic
		end
	end
	
	local extra = {
		extra = gen_extra(vics),
		vic = {},
	}

	for _, vic in ipairs(vics) do
		local f = victory_ani[vic]
		if f then
			extra.vic[vic] = "$(victory." .. vic .. ".title)"
			f(checker, extra)
			flow.sleep(5)
--			extra.vic[vic] = "$(victory." .. vic .. ")"
			vdesktop.set_text("phase", extra)
		end
	end

	local focus_state = {}
	while true do
		mouse.get(focus_state)	
		if mouse.click(focus_state, "left") then
			break
		end
		flow.sleep(0)
	end

	card.next_era()

	return "nextgame"
end
