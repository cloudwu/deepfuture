local vdesktop = require "visual.desktop"
local flow = require "core.flow"
local vtips = require "visual.tips".layer "hud"
local vcard = require "visual.card"
local card = require "gameplay.card"
local rules = require "core.rules".phase
local challenge_rules = require "core.rules".challenge
local ui = require "core.rules".ui
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local track = require "gameplay.track"
local vmap = require "visual.map"
local map = require "gameplay.map"
local look = require "gameplay.look"
local sync = require "gameplay.sync"
local lost_sectors = require "gameplay.lostsectors"

global pairs, print, ipairs, print_r, error, next, print_r, next, assert

local RIVAL_TOKEN <const> = ui.map.token

local function challenge(challenge_card)
	card.pickup("challenge", challenge_card)
	local back = challenge_card._back
	challenge_card._back = nil
	vdesktop.replace("colony", back, challenge_card)
	vdesktop.transfer("colony", challenge_card, "float")
	
	-- mark the cards can avoid challenge
	local need_suit = challenge_card.suit
	local suits = { [need_suit] = true }
	local cards = card.find_upkeep(suits, {})
	card.find_suit("colony", suits, cards)
	card.find_suit("hand", suits, cards)

	local function set_mask(flag)
		vcard.mask(challenge_card, flag)
		for c in pairs(cards) do
			vcard.mask(c, flag)
		end
	end
	set_mask(true)

	local focus_state = {}
	local desc = {
		challenge_suit = card.suit_info(challenge_card),
	}
	if next(cards) == nil then
		desc.nochoice = "$(tips.challenge.nochoice)"
	else
		desc.choice = "$(tips.challenge.choice)"
	end
	
	local accept
	
	while true do
		if focus.get(focus_state) then
			if focus_state.object == challenge_card then
				vtips.set ("tips.challenge.accept", desc)
			elseif cards[focus_state.object] then
				if card.upkeep(focus_state.object) > 0 then
					desc.suit = card.payment_text(focus_state.object)
					vtips.set ("tips.challenge.upkeep", desc)
				else
					vtips.set ("tips.challenge.card", desc)
				end
			else
				vtips.set ("tips.challenge.invalid", desc)
			end
		elseif focus_state.active == "discard" then
			desc.seen = card.seen()
			if desc.seen > 0 then
				vtips.set("tips.look.pile", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c, where = focus.click "left"
		if c == challenge_card then
			accept = true
			break
		elseif cards[c] then
			-- avoid
			if card.upkeep(c) > 0 then
				-- use upkeep
				card.upkeep_change(c, -1)
			else
				-- discard
				card.pickup(where, c)
				card.discard(c)
				vdesktop.transfer(where, c, "deck")
			end
			break
		elseif where == "discard" then
			set_mask()
			local n = card.seen()
			if n > 0 then
				look.start(n)
			end
			set_mask(true)
		end
		flow.sleep(0)
	end

	set_mask()
	
	vtips.set()
	
	return accept
end

local order = { "M", "S", "X", "C" }

local function gen_effect(desc, type)
	local name = challenge_rules[type]
	desc.challenge_name = "$(challenge." .. name .. ".name)"
	local rule = challenge_rules[name]
	if rule.world then
		desc.challenge_desc = "$(tips.challenge.desc.newciv)"
		desc.rival = rule.world
	elseif rule.rival then
		desc.challenge_desc = "$(tips.challenge.desc.trackrival)"
		desc.rival = rule.rival
		for _, t in ipairs(order) do
			if rule[t] then
				desc.track = "$(hud." .. t .. ".logo)" .. "$(hud." .. t .. ")"
				desc.dec = rule[t]
				break
			end
		end
	else
		desc.challenge_desc = "$(tips.challenge.desc.track)"
		local track_key = "track1"
		local dec_key = "dec1"
		for _, t in ipairs(order) do
			if rule[t] then
				desc[track_key] = "$(hud." .. t .. ".logo)" .. "$(hud." .. t .. ")"
				desc[dec_key] = rule[t]
				track_key = "track2"
				dec_key = "dec2"
			end
		end
		if desc.dec2 > desc.dec1 then
			desc.track1, desc.track2 = desc.track2, desc.track1
			desc.dec1, desc.dec2 = desc.dec2, desc.dec1
		end
	end
end

local function wait_moving(where, c)
	repeat
		flow.sleep(1)
	until not vdesktop.moving(where, c)
end

local function accept_challenge(card_suit)
	local card_value = card.draw_discard()
	vcard.mask(card_suit, true)
	vcard.mask(card_value, true)
	vdesktop.add("deck", card_value)	
	vdesktop.transfer("deck", card_value, "float")
	flow.sleep(0)
	local challenge_type = card_value.value .. card_suit.suit
	local challenge_type_text = card_value.value .. card.suit_info(card_suit)
	local desc = {
		suit = challenge_type_text,
		effect ="$(tips.challenge.desc)",
	}
	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			if focus_state.object == card_suit then
				desc.card = card.suit_info(card_suit)
				gen_effect(desc, challenge_type)
				vtips.set("tips.challenge.effect", desc)
			elseif focus_state.object == card_value then
				desc.card = card_value.value
				gen_effect(desc, challenge_type)
				vtips.set("tips.challenge.effect", desc)
			else
				vtips.set()
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c = focus.click "left"
		if c == card_suit or c == card_value then
			card.discard(card_suit)
			vcard.mask(card_suit)
			vdesktop.transfer("float", card_suit, "deck")
			flow.sleep(5)
			card.discard(card_value)
			vcard.mask(card_value)
			vdesktop.transfer("float", card_value, "deck")
			flow.sleep(5)
			vtips.set()
			wait_moving("deck", card_value)
			return challenge_type
		end
		flow.sleep(0)
	end
end

local function interval()
	flow.sleep(10)
end

local function add_rival(lost, sector, n)
	if sector == nil then
		local c = card.draw_discard()
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "float")
		wait_moving("float", c)
		interval()
		local value = c.value
		local ncard = card.find_value("neutral", value)
		if ncard then
			vdesktop.transfer("float", c, "deck")
			flow.sleep(5)
			vdesktop.transfer("neutral", ncard, "float")
			wait_moving("float", ncard)
			interval()
			vdesktop.transfer("float", ncard, "neutral")
			wait_moving("neutral", ncard)
			sector = ncard.sector
		else
			vdesktop.transfer("float", c, "deck")
			flow.sleep(5)
			-- random sector
			local c1 = card.draw_discard()
			local c2 = card.draw_discard()
			vdesktop.add("deck", c1)
			vdesktop.transfer("deck", c1, "float")
			vdesktop.add("deck", c2)
			vdesktop.transfer("deck", c2, "float")
			sector = c1.value * 10 + c2.value
			wait_moving("float", c2)
			interval()
			vdesktop.transfer("float", c1, "deck")
			vdesktop.transfer("float", c2, "deck")
			wait_moving("deck", c2)
		end
		vmap.focus(sector)
	end
	local lost_sector = true
	while n > 0 do
		local dec = map.sub_player(sector, 1)
		if dec > 0 then
			vmap.focus(sector)
			n = n - 1
			if n == 0 then
				vdesktop.set_text("phase", { extra = false })
			else
				vdesktop.set_text("phase", { extra = RIVAL_TOKEN:rep(n) })
			end
			interval()
		else
			lost_sector = false
			break
		end
	end
	if lost_sector then
		lost[sector] = true
	end
	while n > 0 do
		local rival = map.add_neutral(sector, 1)
		if rival == 0 then
			n = n - 1
			if n == 0 then
				vdesktop.set_text("phase", { extra = false })
			else
				vdesktop.set_text("phase", { extra = RIVAL_TOKEN:rep(n) })
			end
			interval()
		else
			break
		end
	end
	if n > 0 then
		local c = card.draw_discard()
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "float")
		wait_moving("float", c)
		interval()
		vdesktop.transfer("float", c, "deck")
		wait_moving("deck", c)
		local value = c.value
		local neighbor = map.neighbor(sector, value)
		if neighbor then
			vmap.focus(neighbor)
			return add_rival(lost, neighbor, n)
		end
	end
end

local function set_title_rival(rival)
	for i = 1, rival do
		local extra = 
		vdesktop.set_text("phase", { extra = RIVAL_TOKEN:rep(i) })
		interval()
	end
end

local function add_neutral(lost, rival)
	local draw = card.count "draw" + card.count "discard"
	local c
	for i = 1, draw do
		c = card.draw_discard()
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "float")
		flow.sleep(5)
		if c.type ~= "world" then
			vdesktop.transfer("float", c, "deck")
		else
			break
		end
	end
	if not c then
		-- todo : no more cards
		return
	end
	wait_moving("float", c)
	set_title_rival(rival)
	-- move this world to neutral
	vdesktop.transfer("float", c, "neutral")
	local last = card.find_value("neutral", c.value)
	if last then
		last = card.pickup("neutral", last)
		card.discard(last)
		vdesktop.transfer("neutral", last, "deck")
	end
	card.putdown("neutral", c)
	wait_moving("neutral", c)
	vmap.focus(c.sector)
	add_rival(lost, c.sector, rival)
	interval()
end

local function execute_challenge(lost, name)
	local rule = challenge_rules[name]
	for _, t in ipairs(order) do
		if rule[t] then
			track.use(t, rule[t])
			flow.sleep(5)
		end
	end
	if rule.rival then
		-- nil : random
		set_title_rival(rule.rival)
		add_rival(lost, nil, rule.rival)
	end
	local rival = rule.world
	if rival then
		add_neutral(lost, rival)
	end
end

return function ()
	sync()
	vdesktop.set_text("phase", { text = "$(phase.challenge)" })
	local lost = {}
	while true do
		local c = card.card("challenge", 1)
		if c == nil then
			-- todo : next round/year"
			vdesktop.set_text("phase", { extra = false } )
			break
		end
		if challenge(c) then
			local ctype = accept_challenge(c)
			execute_challenge(lost, challenge_rules[ctype])
		else
			card.discard(c)
			vdesktop.transfer("float", c, "deck")
		end
	end
	map.set_galaxy(0, 0)
	return lost_sectors(lost)
end
