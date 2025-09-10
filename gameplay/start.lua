local persist = require "gameplay.persist"
local card = require "gameplay.card"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local mouse = require "core.mouse"
local vtips = require "visual.tips".layer "hud"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vmap = require "visual.map"
local rules = require "core.rules".phase
local class = require "core.class"
local desktop = require "gameplay.desktop"
require "gameplay.effect"
local test = require "gameplay.test"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"

global print, ipairs, pairs, print_r, error, tostring, next, assert, require

local UPKEEP_LIMIT <const> = rules.payment.upkeep_limit

local function draw_hands()
	local draw = rules.start.draw - card.count "hand"
	if draw > 0 then
		-- draw to rules.start.draw(5) cards
		for i = 1, draw do
			local c = card.draw_hand()
			if c == nil then
				break
			end
			vdesktop.add("deck", c)
			vdesktop.transfer("deck", c, "hand")
			flow.sleep(5)
		end
	end
end

local function discard_hand_limit()
	local discard = card.count "hand" - rules.start.hand_limit
	if discard > 0 then
		vdesktop.set_text("phase", { text = "$(phase.discard)" })
		-- discard random card
		local focus_state = {}
		local desc = { limit = rules.start.hand_limit }
		local function wait_click(discard_card)
			while true do
				if mouse.get(focus_state) then
					if focus_state.object == discard_card then
						vtips.set("tips.discard.focus", desc)
					elseif focus_state.object then
						vtips.set("tips.discard.invalid", desc)
					else
						vtips.set()
					end
				end
				if mouse.click(focus_state, "left") == discard_card then
					vcard.mask(discard_card)
					vtips.set()
					return
				end
				flow.sleep(0)
			end
		end
		
		for i = 1, discard do
			local c = card.discard_random_hand()
			vdesktop.transfer("hand", c, "float")
			vcard.mask(c, true)
			flow.sleep(0)
			wait_click(c)
			vdesktop.transfer("float", c, "deck")
		end
	end
end

local adv_focus = {}

-- todo: focus status manager

function adv_focus.art()
	vdesktop.draw_pile_focus(nil)
	track.focus("C", true)
end

function adv_focus.infrastructure()
	vdesktop.draw_pile_focus(nil)
	track.focus(true)	-- all
end

function adv_focus.economy()
	vdesktop.draw_pile_focus(nil)
	track.focus(true)	-- all
end

function adv_focus.exploration()
	vdesktop.draw_pile_focus(nil)
	track.focus(true)	-- all
end

function adv_focus.history()
	vdesktop.draw_pile_focus(true)
end

local start_adv = {}

function start_adv.art()
	track.advance("C", 1)
end

function start_adv.computation(advs)
	local c = card.draw_hand() or error "No more card"
	advs:add(c, "hand")
	vdesktop.add("deck", c)
	vdesktop.transfer("deck", c, "hand")
	flow.sleep(0)	-- release focus
	advs:update()
	advs:discard_one_card ("start", "computation", false)
end

function start_adv.history(advs, focus_state)
	card.add_seen()
	advs:look_drawpile(focus_state)
end

local function dec_tracks()
	local focus_state = {}
	local desc = { effect = "$(adv.economy.name) $(adv.economy.desc)" }
	track.focus(true)
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "track" then
				local what = focus_state.object	-- C/M/S/X
				track.focus(false)
				desc.type = "$(hud." .. what .. ")"
				if track.check(what, -1) then
					vtips.set("tips.track.invalid", desc)
				else
					vtips.set("tips.track.valid", desc)
					track.focus(what, true)
				end
			elseif focus_state.object then
				vtips.set "tips.track.out"
			else
				-- focus all
				track.focus(true)
				vtips.set()
			end
		end
		
		local t, where = mouse.click(focus_state, "left")
		if where == "track" then
			if not track.check(t, -1) then
				track.use(t, 1)
				track.focus(false)
				vtips.set()
				return
			end
		end
		flow.sleep(0)
	end
end

function start_adv.economy(advs)
	advs:reset()
	dec_tracks()
	-- draw 2 cards
	local c1 = card.draw_hand()
	local c2 = card.draw_hand()
	if c1 then
		advs:add(c1, "hand")
		vdesktop.add("deck", c1)
		vdesktop.transfer("deck", c1, "hand")
		flow.sleep(5)
	end
	if c2 then
		advs:add(c2, "hand")
		vdesktop.add("deck", c2)
		vdesktop.transfer("deck", c2, "hand")
	end
	advs:update()
end

function start_adv.infrastructure(advs)
	local r = {}
	local n = 1
	while true do
		local c = card.card("homeworld", n)
		if c == nil then
			break
		end
		n = n + 1
		if card.upkeep(c) < UPKEEP_LIMIT then
			r[c] = true
		end
	end
	advs:reset()
	dec_tracks()
	-- add upkeep
	for c in pairs(r) do
		vcard.mask(c, true)
	end
	local focus_state = {}
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "homeworld" then
				local c = focus_state.object
				if r[c] then
					vtips.set "tips.upkeep.valid"
				else
					vtips.set "tips.upkeep.full"
				end
			elseif focus_state.object then
				vtips.set "tips.upkeep.invalid"
			else
				vtips.set()
			end
		end
		local c = mouse.click(focus_state, "left")
		if c and r[c] then
			card.upkeep_change(c, 1)
			break
		end
		flow.sleep(0)
	end
	advs:update()
end

local function set_sector_mask(sectors, flag)
	for sec in pairs(sectors) do
		vmap.set_sector_mask(sec, flag)
	end
end

local function discard_planets(advs, cards)
	local drop_homeworld
	for c in pairs(cards) do
		advs:remove(c)
		local p = card.pickup("colony", c)
		if p then
			card.discard(p)
			vdesktop.transfer("colony", p, "deck")
		elseif card.pickup("homeworld", c) then
			drop_homeworld = c
		end
		flow.sleep(5)
	end
	if drop_homeworld then
		local succ = desktop.relocate_homeworld(drop_homeworld)
		assert(succ, "Lost all colony")
	end
end

local function exploration(advs, sectors)
	set_sector_mask(sectors, true)
	local danger
	local function clear_danger()
		if danger then
			for _, c in ipairs(danger) do
				vcard.mask(c)
			end
		end
		danger = nil
	end
	local function set_danger(pile)
		if pile == nil then
			clear_danger()
		elseif pile ~= danger then
			clear_danger()
			danger = pile
			for i, c in ipairs(danger) do
				vcard.mask(c, true)
			end
		end
	end
	local desc = {}
	-- choose from
	local focus_state = {}
	local from_sector
	local to_sector
	while true do
		if mouse.get(focus_state) then
			local sec = focus_state.object
			local where = focus_state.active
			if where == "map" then
				local danger_pile = sectors[sec]
				desc.from = sec
				if danger_pile == nil then
					vtips.set ("tips.exploration.invalid", desc)
					set_danger()
				elseif danger_pile == false then
					vtips.set ("tips.exploration.from", desc)
					set_danger()
				else
					vtips.set ("tips.exploration.danger", desc)
					set_danger(danger_pile)
				end
			elseif focus_state.object then
				vtips.set ("tips.exploration.invalid", desc)
				set_danger()
			else
				vtips.set()
			end
		end
		local sec, region = mouse.click(focus_state, "left")
		if sec and region == "map" then
			from_sector = sec
			break
		end
		flow.sleep(0)
	end
	vtips.set()
	-- choose to
	local focus_state = {}
	local neighbor = map.find_neighbor(from_sector)
	local danger_cards = {}
	set_sector_mask(sectors, false)
	set_sector_mask(neighbor, true)
	if sectors[from_sector] then
		-- danger
		set_danger(sectors[from_sector])
		for _, c in pairs(sectors[from_sector]) do
			danger_cards[c] = true
		end
	end
	
	while true do
		if mouse.get(focus_state) then
			local sec = focus_state.object
			local where = focus_state.active
			if where == "map" then
				desc.to = sec
				if neighbor[sec] then
					vtips.set ("tips.exploration.to", desc)
				else
					vtips.set ("tips.exploration.dest", desc)
				end
			elseif danger_cards[sec] then
				vtips.set ("tips.exploration.cancel", desc)
			elseif focus_state.object then
				vtips.set ("tips.exploration.dest", desc)
			else
				vtips.set()
			end
		end
		local sec, region = mouse.click(focus_state, "left")
		if sec then
			if danger_cards[sec] then
				-- cancel
				set_danger()
				set_sector_mask(neighbor, false)
				return exploration(advs, sectors)
			end
			if region == "map" and neighbor[sec] then
				set_danger()
				to_sector = sec
				break
			end
		end
		local sec, region = mouse.click(focus_state, "right")
		if sec and danger_cards[sec] then
			-- cancel
			set_danger()
			set_sector_mask(neighbor, false)
			return exploration(advs, sectors)
		end
		flow.sleep(0)
	end
	-- move from to
	map.move(from_sector, to_sector)
	
	if next(danger_cards) then
		discard_planets(advs, danger_cards)
	end
	-- todo: discard danger
	set_sector_mask(neighbor, false)
end

function start_adv.exploration(advs)
	local sectors = map.find_ctrl(false)	-- true for expand
	local only_sector
	for sector, n in pairs(sectors) do
		local cards = card.sector(sector)
		if cards then
			if n == 1 and only_sector == nil then
				-- the first sector contains planet with only 1 people
				only_sector = sector
			else
				only_sector = false
			end
			if n == 1 then
				-- danger
				sectors[sector] = cards
			else
				sectors[sector] = false
			end
		else
			sectors[sector] = false
		end
	end
	if only_sector then
		if card.check_only_sector(only_sector) then
			sectors[only_sector] = nil
		else
			sectors[only_sector] = card.sector(only_sector)
		end
	end
	
	-- set mask
	advs:reset()
	dec_tracks()
	exploration(advs, sectors)
	advs:update()
end

return function ()
	loadsave.sync_history()
	loadsave.sync_game "start"
	vdesktop.set_text("phase", {
		text = "$(phase.start)",
	})
	draw_hands()
	test.patch "start"
	sync()
	
	local advs = class.effect "START"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"
	
	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "start",
			adv_focus = adv_focus,
			adv_func = start_adv,
		}
		advs:discard_used_cards()
		track.focus(false)
	end
	discard_hand_limit()

	return flow.state.action
end
