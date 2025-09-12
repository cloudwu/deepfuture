local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local card = require "gameplay.card"
local class = require "core.class"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vmap = require "visual.map"
local vtips = require "visual.tips".layer "hud"
local mouse = require "core.mouse"
local vbutton = require "visual.button"
local loadsave = require "core.loadsave"
local vcard = require "visual.card"
local sync = require "gameplay.sync"
local desktop = require "gameplay.desktop"

global pairs, ipairs, setmetatable, print, next, print_r, assert, error

local adv_focus = {}

function adv_focus.communication()
	track.focus("M", true)
end
	
function adv_focus.astronomy()
	track.focus("X", true)
end

function adv_focus.religion()
	track.focus("C", true)
end

local function check_wonder(wonders)
	if next(wonders) == nil then
		return
	end
	local suits = {}
	for _, w in pairs(wonders) do
		suits[w.suit] = true
	end
	local hands = card.pile "hand"
	for i, c in ipairs(hands) do
		if suits[c.suit] then
			hands[c] = c.suit
		end
		hands[i] = nil
	end
	if next(hands) then
		return hands
	end
end

local TRACK_WONDER = {
	C = true,
	M = true,
	X = true,
	S = true,
}

local function ignore_unused_wonder(wonder)
	for sec, w in pairs(wonder) do
		local symbol = w.symbol
		if TRACK_WONDER[symbol] then
			if not track.check(symbol, 1) then
				-- already full
				wonder[sec] = nil
			end
		end
	end
end

local function excute_wonder(w, sec, value)
	local symbol = w.wonder
	if symbol == "T" then
		-- draw cards
		for i = 1, value do
			local c = card.draw_hand()
			vdesktop.add("deck", c)
			vdesktop.transfer("deck", c, "hand")
			flow.sleep(5)
		end
	elseif symbol == "P" then
		-- add cubes
		for i = 1, value do
			vmap.focus(sec)
			map.add_player(sec, 1)
			flow.sleep(5)
		end
	else
		if not TRACK_WONDER[symbol] then
			error("Invalid wonder", symbol)
		end
		-- add tracks
		track.focus(symbol)
		track.advance(symbol, value)
		flow.sleep(10)
		track.focus(false)
	end
end

local function find_sun(wonders)
	-- draw cards first
	for sec, w in pairs(wonders) do
		if w.symbol == "T" then
			return sec, w
		end
	end
	return next(wonders)
end

local function choose_wonder(wonders, cards)
	local sec, w = find_sun(wonders)
	vdesktop.set_text("phase", { text = "$(phase.wonder)" })
	local desc = {
		sector = sec,
		extra = "$(wonder." .. w.wonder .. ")",
		suit = card.suit_info(w),
	}
	vdesktop.set_text("phase", desc)
	vtips.set()
	vmap.set_sector_mask(sec, true)
	for c in pairs(cards) do
		if c.suit ~= w.suit then
			cards[c] = nil
		end
	end
	
	local discard = vdesktop.draw_pile_focus()
	
	local confirm = desktop.confirm(discard, cards)
	confirm:set_mask(true)

	local focus_state = {}
	local click
	while true do
		if mouse.get(focus_state) then
			local c = focus_state.object
			if cards[c] then
				desc.n = c.value
				vtips.set("tips.wonder.active", desc)
				vdesktop.set_text("phase", desc)
			elseif c == discard then
				vtips.set("tips.wonder.cancel", desc)
			elseif c then
				desc.n = false
				vtips.set("tips.wonder.active.advice", desc)
				vdesktop.set_text("phase", desc)
			else
				vtips.set()
			end
		end
		click = mouse.click(focus_state, "left")
		if cards[click] then
			break
		end
		if click == discard and confirm:click() then
			click = nil
			break
		end
		confirm:update()
		flow.sleep(0)
	end

	confirm:set_mask()
	
	if click then
		card.pickup("hand", click)
		card.discard(click)
		vdesktop.transfer("hand", click, "deck")
		excute_wonder(w, sec, click.value)
	end
	vmap.set_sector_mask(sec)
	wonders[sec] = nil
end

return function()
	loadsave.sync_game "expand"
	sync()
	vdesktop.set_text("phase", { text = "$(phase.action)" })
	local dist = 1
	local spacecraft = 0
	local start_region = map.expand_start(dist)
	local function mark_start(flag)
		for sec in pairs(start_region) do
			vmap.set_sector_mask(sec, flag)
		end
	end
	
	local expand_adv = {}

	function expand_adv.communication()
		track.advance("M", 1)
	end

	function expand_adv.astronomy()
		track.advance("X", 1)
	end

	function expand_adv.religion()
		track.advance("C", 2)
	end

	function expand_adv.spacecraft()
		spacecraft = spacecraft + 1
	end

	function expand_adv.ftl()
		dist = dist + 1
		if start_region then
			start_region = map.expand_start(dist)
			mark_start(true)
		else
			map.expand(dist)
		end
	end
	
	local map_message = {}
	local desc = {}

	function map_message.focus(sec)
		desc.sec = sec
		if start_region then
			-- choose start
			if start_region[sec] then
				vtips.set ("tips.expand.choose.valid", desc)
			else
				local n = map.player_ctrl(sec)
				if n then
					if n == 1 then
						desc.reason = "$(tips.expand.invalid.lost)"
					else
						desc.reason = "$(tips.expand.invalid.block)"
					end
				else
					desc.reason = "$(tips.expand.invalid.noctrl)"
				end
				vtips.set ("tips.expand.choose.invalid", desc)
			end
		else
			local ok, reason = map.check_expand(sec, spacecraft)
			if ok then
				-- can expand
				if map.expand_back(sec, true) then
					desc.undo = "$(tips.expand.undo)"
				else
					desc.undo = nil
				end
				vtips.set ("tips.expand.valid", desc)
			else
				if map.expand_back(sec, true) then
					desc.undo = "$(tips.expand.undo)"
				else
					desc.undo = nil
				end
				desc.reason = reason
				vtips.set ("tips.expand.invalid", desc)
			end
		end
	end
	
	function map_message.click(sec, button)
		if start_region then
			if button == "left" then
				if start_region[sec] then
					mark_start()
					map.expand_choose_start(sec)
					start_region = nil
					map.expand(dist)
					desc.from = sec
				end
			end
		elseif button == "left" then
			if map.check_expand(sec, spacecraft) then
				map.expand_people(sec, 1)
			end
		elseif button == "right" then
			map.expand_back(sec)
		end
		map_message.focus(sec)
	end

	vdesktop.set_text("phase", { extra = "[blue]$(EXPAND)[n]" })

	mark_start(true)

	local advs = class.effect "EXPAND"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"

	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "expand",
			adv_focus = adv_focus,
			adv_func = expand_adv,
			map_message = map_message,
		}
		advs:discard_used_cards()
		advs:reset()
	end
	
	-- confirm
	local button = {
		text = "button.expand.confirm",
	}
	
	local function expand_check()
		local n, start = map.expand_count()
		button.n = n
		button.from = start
		if not n then
			button.disable = true
		else
			button.disable = nil
		end
		vbutton.update "button1"
	end

	vdesktop.button_enable("button1", button)
	expand_check()

	local focus_state = {}
	
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "map" then
				map_message.focus(focus_state.object)
			elseif focus_state.active == "button1" then
				if button.disable then
					vtips.set ("tips.expand.confirm.invalid", button)
				else
					vtips.set ("tips.expand.confirm", button)
				end
			else
				vtips.set()
			end
		end
		local c, btn = mouse.click(focus_state, "left")
		if c then
			if btn == "button1" then
				break
			elseif btn == "map" then
				map_message.click(c, "left")
				expand_check()
			end
		end
		local c, btn = mouse.click(focus_state, "right")
		if btn == "map" then
			map_message.click(c, "right")
			expand_check()
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	
	local wonder = map.expand_wonder()
	map:reset()
	if wonder then
		ignore_unused_wonder(wonder)
		while true do
			local cards = check_wonder(wonder)
			if cards == nil then
				break
			end
			choose_wonder(wonder, cards)
			flow.sleep(0)
		end
	end
	
	flow.sleep(1)
	
	return flow.state.action
end
