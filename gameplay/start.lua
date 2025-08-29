local persist = require "gameplay.persist"
local card = require "gameplay.card"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local focus = require "core.focus"
local vtips = require "visual.tips".layer "hud"
local vbutton = require "visual.button"
local track = require "gameplay.track"
local advancement = require "gameplay.advancement"
local map = require "gameplay.map"
local vmap = require "visual.map"
local show_desc = require "gameplay.desc"
local rules = require "core.rules".phase
local class = require "core.class"
local look = require "gameplay.look"
require "gameplay.effect"
local test = require "gameplay.test"

global print, ipairs, pairs, print_r, error, tostring, next

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
		vdesktop.set_text("phase", "$(phase.discard)")
		-- discard random card
		local focus_state = {}
		local desc = { limit = rules.start.hand_limit }
		local function wait_click(discard_card)
			while true do
				if focus.get(focus_state) then
					if focus_state.object == discard_card then
						vtips.set("tips.discard.focus", desc)
					else
						vtips.set("tips.discard.invalid", desc)
					end
				elseif focus_state.lost then
					vtips.set()
				end
				if focus.click "left" == discard_card then
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

local function look_drawpile(advs, button)
	local n = card.seen()
	if n == 0 then
		return
	end
	if button then
		vdesktop.button_enable("button1", nil)
	end
	advs:reset()
	look.start(n)
	advs:update()
	if button then
		vdesktop.button_enable("button1", button)
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

local function advancement_unfocus()
	vdesktop.draw_pile_focus(nil)
	track.focus(false)	-- disable all focus track
end

local function advancement_focus(what)
	local f = adv_focus[what]
	if f then
		f()
	else
		advancement_unfocus()
	end
end

local start_adv = {}

function start_adv.art()
	track.advance("C", 1)
end

local function discard_one_card(advs)
	vdesktop.set_text("phase", "$(phase.discard)")
	local discards = {}
	local n = 1
	while true do
		local c = card.card("hand", n)
		if c == nil then
			break
		end
		if not advs:is_used(c) then
			discards[#discards+1] = c
		end
		n = n + 1
	end
	advs:reset()
	for _, c in ipairs(discards) do
		vcard.mask(c, true)
	end
	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "hand" then
				if advs:is_used(focus_state.object) then
					vtips.set "tips.discard.computation.invalid"
				else
					vtips.set "tips.discard.computation"
				end
			else
				vtips.set()
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c = focus.click "left"
		if c and not advs:is_used(c) then
			local discard_card = card.pickup("hand", c)
			if discard_card then
				card.discard(discard_card)
				vdesktop.set_text("phase", "$(phase.start)")
				for _, c in ipairs(discards) do
					vcard.mask(c)
				end
				return discard_card
			end
		end
		flow.sleep(0)
	end
end

function start_adv.computation(advs)
	local c = card.draw_hand() or error "No more card"
	advs:add(c, "hand")
	vdesktop.add("deck", c)
	vdesktop.transfer("deck", c, "hand")
	flow.sleep(0)	-- release focus
	advs:update()
	local discard = discard_one_card(advs)
	advs:remove(discard)
	vdesktop.transfer("hand", discard, "deck")
end

function start_adv.history(advs)
	card.add_seen()
	look_drawpile(advs)
end

local function dec_tracks()
	local focus_state = {}
	local desc = { effect = "$(adv.economy.name) $(adv.economy.desc)" }
	local last_focus
	local function focus_track(what)
		if last_focus then
			track.focus(last_focus, false)
		end
		if what then
			track.focus(what, true)
			last_focus = what
		else
			last_focus = nil
		end
	end
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "track" then
				local what = focus_state.object	-- C/M/S/X
				desc.type = "$(hud." .. what .. ")"
				if track.check(what, -1) then
					vtips.set("tips.track.invalid", desc)
					focus_track()
				else
					vtips.set("tips.track.valid", desc)
					focus_track(what)
				end
			else
				focus_track()
				vtips.set "tips.track.out"
			end
		elseif focus_state.lost then
			focus_track()
			vtips.set()
		end
		
		local t, where = focus.click "left"
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
		vdesktop.add("deck", c1)
		vdesktop.transfer("deck", c1, "hand")
		flow.sleep(5)
	end
	if c2 then
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
		if focus.get(focus_state) then
			if focus_state.active == "homeworld" then
				local c = focus_state.object
				if r[c] then
					vtips.set "tips.upkeep.valid"
				else
					vtips.set "tips.upkeep.full"
				end
			else
				vtips.set "tips.upkeep.invalid"
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c = focus.click "left"
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

local function choose_new_homeworld()
	vtips.set()
	local colony = {}
	local n = 1
	while true do
		local c = card.card("colony", n)
		if not c then
			break
		end
		vcard.mask(c, true)
		colony[n] = c
		n = n + 1
	end
	local focus_state = {}
	local new_homeworld
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "colony" then
				vtips.set "tips.homeworld.set"
			else
				vtips.set "tips.homeworld.invalid"
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local sec, region = focus.click "left"
		if sec and region == "colony" then
			new_homeworld = card.pickup("colony", sec)
			break
		end
		flow.sleep(0)
	end
	for _, c in ipairs(colony) do
		vcard.mask(c)
	end
	card.putdown("homeworld", new_homeworld)
	vdesktop.transfer("colony", new_homeworld, "homeworld")
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
			card.upkeep_change(c)	-- clear upkeep
			drop_homeworld = c
		end
		flow.sleep(5)
	end
	if drop_homeworld then
		local value = drop_homeworld.value
		local n = card.find_value("neutral", value)
		if n then
			vdesktop.transfer("neutral", n, "deck")
			flow.sleep(5)
		end
		vdesktop.transfer("homeworld", drop_homeworld, "neutral")
		choose_new_homeworld()
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
		if focus.get(focus_state) then
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
			else
				vtips.set ("tips.exploration.invalid", desc)
				set_danger()
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local sec, region = focus.click "left"
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
		if focus.get(focus_state) then
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
			else
				vtips.set ("tips.exploration.dest", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local sec, region = focus.click "left"
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
		local sec, region = focus.click "right"
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

local function choose_cards(advs, n)
	local button = {
		text = "button.start",
		n = n,
	}
	local desc = {
		seen = nil,
	}
	local card_tips = {}
	local focus_state = {}
	
	vdesktop.button_enable("button1", button)
	
	while true do
		if focus.get(focus_state) then
			local where = focus_state.active
			if where == "button1" then
				vtips.set("tips.start.skip", button)
			elseif where == "discard" then
				desc.seen = card.seen()
				if desc.seen > 0 then
					vtips.set("tips.look.pile", desc)
				end
			else
				local focus = advs:focus(focus_state.object)
				if focus then
					advancement_focus(focus)
					card_tips.adv = advancement.info(focus, "name")
					card_tips.effect = advancement.info(focus, "desc")
					local next_adv = advs:nextadv(focus_state.object)
					if next_adv then
						card_tips.nextadv = advancement.info(next_adv, "name")
						vtips.set("tips.start.card.multiple", card_tips)
					else
						vtips.set("tips.start.card.unique", card_tips)
					end
				else
					vtips.set()
				end
			end
		elseif focus_state.lost then
			vtips.set()
			advancement_unfocus()
		end
		local switch_card, region = focus.click "right"
		if switch_card then
			if advs:can_use(switch_card) then
				local focus = advs:nextadv(switch_card, true)
				if not focus then
					-- unique adv, explain this card
					vtips.set()
					advancement_unfocus()
					show_desc.start {
						region = region,
						card = switch_card,
						name = advs:focus(switch_card),
					}
				else
					advancement_focus(focus)
					card_tips.adv = advancement.info(focus, "name")
					card_tips.effect = advancement.info(focus, "desc")
					local next_adv = advs:nextadv(focus_state.object)
					card_tips.nextadv = advancement.info(next_adv, "name")
					vtips.set("tips.start.card.multiple", card_tips)
				end
			end
		end
		local c, btn = focus.click "left"
		if c then
			if btn == "button1" then
				break
			end
			if advs:can_use(c) then
				advancement_unfocus()
				vtips.set(nil)
				local adv_name = advs:focus(c)
				advs:use(c)
				local f = start_adv[adv_name]
				if f then	-- todo :  remove this after complete all 6 start adv
					vdesktop.button_enable("button1", nil)
					f(advs)
					vdesktop.button_enable("button1", button)
				end
				local n = advs:update()
				if n == 0 then
					-- no more advs available
					break
				end
				advancement_unfocus()
				vtips.set(nil)
				if n ~= button.n then
					button.n = n
					vbutton.update "button1"
				end
			elseif btn == "discard" then
				look_drawpile(advs, button)
			else
				vtips.set(nil)
			end
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	vtips.set(nil)
end

local function sync(where)
	local p = test.get_pile(where)
	local diff = vdesktop.sync(where, p)
	if not diff then
		return
	end
	for _, c in ipairs(diff.discard) do
		print("START TEST DISCARD FROM", where, c)
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
	for _, c in ipairs(diff.draw) do
		print("START TEST DRAW TO", where, c)
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, where)
		flow.sleep(5)
	end
end

local function test_patch()
	test.patch "start"
	sync "hand"
	sync "homeworld"
	sync "colony"
end

local function discard_used_cards(advs)
	local cards = advs:used_cards()
	for _, c in ipairs(cards) do
		if card.pickup("hand", c) then
			card.discard(c)
			vdesktop.transfer("hand", c, "deck")
			flow.sleep(5)
		elseif card.pickup("colony", c) then
			card.discard(c)
			vdesktop.transfer("colony", c, "deck")
			flow.sleep(5)
		end
	end
end

return function ()
	test_patch()
	vdesktop.set_text("phase", "$(phase.start)")
	draw_hands()
	
	local advs = class.effect "START"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"
	
	local n = advs:update()
	if n > 0 then
		choose_cards(advs, n)
		discard_used_cards(advs)
		advs:reset()
	end
	discard_hand_limit()

	return "action"
end
