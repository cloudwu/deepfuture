local genname = require "gameplay.name"
local persist = require "gameplay.persist"
local vcard = require "visual.card"
local math = math
local table = table
local error = error
local advancement = require "gameplay.advancement"
local rules = require "core.rules".phase
local ui = require "core.rules".ui
local util = require "core.util"
local loadsave = require "core.loadsave"

global tostring, setmetatable, ipairs, pairs, print, print_r, assert, tonumber, type, string

local UPKEEP_LIMIT <const> = rules.payment.upkeep_limit
local UPKEEP_LOGO <const> = ui.payment.upkeep

local card = {}

function card.profile(profile, filename)
	loadsave.new_profile (profile, filename)
end

--[[
suits:

S : sun
M : moon
H : heart
K : skull
H : hand
F : foot

value : 1-6
type : blank world tech civ deleted

]]

local actions = util.keys(ui.suit)
table.sort(actions)

local GAME
local DECK
local HISTORY

function card.dump_deck()
	for _, c in ipairs(DECK) do
		print(c, c._marker)
	end
end

local function gen_marker(obj)
	obj._marker = tostring(obj.value) .. card.suit_info(obj)
end

local card_meta = {
	__tostring = function (self)
		return "[CARD " .. self.value .. self.suit .. "]"
	end
}
local function new_card(obj)
	return setmetatable(obj, card_meta)
end

function card.init_deck()
	local init = {}
	local id = 1
	for i = 1, 6 do
		for j = 1, 6 do
			local card = new_card {
				value = i,
				suit = actions[j],
				type = "blank",
				era = 0,
			}
			loadsave.sync_card(id, card)
			gen_marker(card)
			vcard.flush(card)
			init[id] = card; id = id + 1
		end
	end
	DECK = persist.init("deck", init)
	HISTORY = persist.init("history", {
		era = 0
	})
end

local areas = { "draw", "discard", "hand", "neutral", "homeworld", "colony", "challenge" }

function areas.draw(init)
	local n = 1
	for id, card in ipairs(DECK) do
		if card.type ~= "deleted" then
			init[n] = id; n = n + 1
			card._id = id
		end
	end
end

function card.setup()
	local game = {}
	for _, area in ipairs(areas) do
		game[area] = {}
		local init_func = areas[area]
		if init_func then
			init_func(game[area])
		end
	end
	game.seen = 0 -- seen cards of drawpile
	game.upkeep = {}
	GAME = persist.init("game", game)
end

function card.load()
	GAME = persist.get "game"
	HISTORY = persist.get "history"
	DECK = persist.get "deck"
	
	for id, c in ipairs(DECK) do
		c._id = id
		card.gen_desc(c)
		new_card(c)
		
		-- 恢复维护方块视觉显示
		local upkeep_count = GAME.upkeep[id]
		if upkeep_count and upkeep_count > 0 then
			c._upkeep = UPKEEP_LOGO:rep(upkeep_count)
		end
		
		-- 刷新卡片视觉显示
		vcard.flush(c)
	end
end

function card.next_turn()
	HISTORY.year = HISTORY.year + 1
end

function card.turn()
	return HISTORY.year
end

local function draw_card()
	local _ENV = GAME
	global draw, discard, seen
	local n = #draw
	if n == 0 then
		n = #discard
		if n == 0 then
			-- discard pile is empty, draw fail
			return
		end
		-- swap draw pile and discard pile
		draw, discard = discard, draw
	end
	
	if seen == 0 then
		local idx = math.random(n)
		local card = draw[idx]
		draw[idx] = draw[n]
		draw[n] = nil
		return card
	end
	seen = seen - 1
	return table.remove(GAME.draw, 1) or error "No more card"
end

function card.draw_hand()
	local card_id = draw_card()
	if card_id == nil then
		return
	end
	GAME.hand[#GAME.hand+1] = card_id
	return DECK[card_id]
end

function card.add_seen()
	local draw_pile = GAME.draw
	local seen = GAME.seen
	if #draw_pile > seen then
		local idx = math.random(seen+1, #draw_pile)
		seen = seen + 1
		draw_pile[seen], draw_pile[idx] = draw_pile[idx], draw_pile[seen]
		GAME.seen = seen
	end
	return seen
end

function card.seen()
	return GAME.seen
end

function card.add_action(action)
	if not action then
		-- skip
		GAME.action1 = nil
		GAME.action2 = nil
	else
		if GAME.action1 then
			GAME.action2 = action
		else
			GAME.action1 = action
		end
	end
end

function card.action()
	return GAME.action1, GAME.action2
end

function card.puttop(c)
	local id = c._id
	table.insert(GAME.draw, 1, id)
	GAME.seen = GAME.seen + 1
end

function card.look()
	local c = {}
	local draw = GAME.draw
	for i = 1, GAME.seen do
		c[i] = DECK[draw[i]]
	end
	return c
end

function card.draw_discard()
	local card_id = draw_card()
	if card_id == nil then
		return
	end
	GAME.discard[#GAME.discard+1] = card_id
	return DECK[card_id] or error ("No card id " .. tostring(card_id))
end

function card.draw_card()
	local card_id = draw_card()
	if card_id == nil then
		return
	end
	return DECK[card_id]
end

function card.draw_type(type)
	local n = #GAME.draw + #GAME.discard
	for i = 1, n do
		local card = draw_card()
		card = DECK[card]
		if card.type == type then
			return card
		else
			GAME.discard[#GAME.discard+1] = card._id
		end
	end
end

function card.plan_blankcard()
	local newcard = #DECK + 1
	
	local card = new_card {
		_id = nil,
		type = "blank",
		era = HISTORY.era,
		suit = "P",	-- placeholder
		value = 0,
	}
	loadsave.sync_card(newcard, card)
	card._id = newcard
	DECK[newcard] = card
	return card
end

local function sync_adv(adv)
	if adv == nil then
		return
	end
	return {
		suit = adv.suit,
		value = adv.value,
		era = adv.era,
		chosen = adv.chosen
	}
end

function card.sync(c)
	-- 验证卡片数据完整性
	if not c.type or not c.suit or not c.value or not c.era then
		return -- 不保存无效数据
	end
	
	local data = {
		type = c.type,
		suit = c.suit,
		value = c.value,
		name = c.name,
		sector = c.sector,
		era = c.era,
		adv1 = sync_adv(c.adv1),
		adv2 = sync_adv(c.adv2),
		adv3 = sync_adv(c.adv3),
	}
	if c.type == "civ" then
		data.world = c.world
		data.tech = c.tech
		data.victory = c.victory
		data.advancement = c.advancement
	end
	loadsave.sync_card(c._id, data)
end

function card.blank_tech(c)
	c.type = "tech"
	c.era = HISTORY.era
	vcard.flush(c)
end

function card.generate_newcard()
	local card1 = draw_card()
	local card2 = draw_card()
	if not (card1 and card2) then
		-- no 2 cards
		return
	end
	local n = #GAME.discard
	GAME.discard[n+1] = card1
	GAME.discard[n+2] = card2

	card1 = DECK[card1]
	card2 = DECK[card2]
	
	local newcard = #DECK + 1
	
	local card = new_card {
		_id = nil,
		value = card1.value,
		suit = card2.suit,
		type = "blank",
		era = HISTORY.era,
	}
	loadsave.sync_card(newcard, card)
	card._id = newcard
	gen_marker(card)
	DECK[newcard] = card
	return card, card1, card2
end

local function convert_adv(advname)
	local c = advancement.config(advname)
	if c then
		return {
			suit = c.suit,
			value = c.value,
			era = HISTORY.era,
		}
	end
end

function card.next_era()
	HISTORY.era = HISTORY.era + 1
	HISTORY.year = HISTORY.era * 1000
end

function card.pickup(where, card)
	local id = card._id
	local area = GAME[where]
	for i, c in ipairs(area) do
		if c == id then
			table.remove(area, i)
			return card
		end
	end
end

function card.find_value(where, value)
	local area = GAME[where]
	for i, id in ipairs(area) do
		local c = DECK[id]
		if c.value == value then
			return c
		end
	end
end

function card.putdown(where, card)
	local id = card._id
	local area = GAME[where]
	for i, c in ipairs(area) do
		if c == id then
			return
		end
	end
	if where == "homeworld" and card.type == "world" then
		table.insert(area,1,id)
	else
		if id == GAME.settling then
			assert(where == "colony")
			GAME.settling = nil
		end
		area[#area+1] = id
	end
end

function card.drophand()
	table.move(GAME.hand, 1, #GAME.hand, #GAME.discard + 1, GAME.discard)
	GAME.hand = {}
end

function card.discard(card)
	if card._upkeep then
		card._upkeep = nil	-- clear any upkeep cube
		GAME.upkeep[card._id] = nil
	end
	GAME.discard[#GAME.discard + 1] = card._id
end

function card.count(pile)
	return #GAME[pile]
end

function card.discard_random_hand()
	local n = math.random(#GAME.hand)
	local id = table.remove(GAME.hand, n)
	GAME.discard[#GAME.discard+1] = id
	return DECK[id]
end

function card.cleanup()
	persist.drop "game"
end

local function gen_adv_desc(adv)
	if adv == nil then
		return
	end
	if adv.value == nil then
		assert(adv.suit, "Missing adv.suit")
		adv._suit = card.suit_info(adv)
		adv._name = nil
		adv._stage = nil
		adv._desc = nil
	else
		local adv_name = advancement.name(adv.suit, adv.value)
		local prefix = "$(adv."..advancement.name(adv.suit, adv.value).."."
		adv._suit = card.suit_info(adv)
		adv._name = advancement.info(adv_name, "name").. "." .. adv.era
		adv._desc = advancement.info(adv_name, "desc")
		local stage = advancement.stage(adv.suit, adv.value)
		adv._stage = "[[$(".. stage .. ".card)]"
		adv._stage_focus = "[blue]" .. adv._stage .. "[n]"
		adv._stage_use = "[40000000]" .. adv._stage .. "[n]"
		adv._stage_normal = adv._stage
	end
	if adv.chosen then
		adv._circle = "[circle]"
	end
end

function card.add_adv_suit(c, suit)
	local adv = { suit = suit }
	local index
	if c.adv1 == nil then
		index = "adv1"
	elseif c.adv2 == nil then
		index = "adv2"
	elseif c.adv3 == nil then
		index = "adv3"
	else
		return
	end
	c[index] = adv
	gen_adv_desc(adv)
	return index
end

function card.add_adv_value(c, adv_index, value, era)
	local adv = c[adv_index] or error ("Invalid adv " .. adv_index)
	adv.value = value
	adv.era = era
	gen_adv_desc(adv)
end

function card.gen_desc(c)
	if c.type == "world" or c.type == "tech" then
		gen_adv_desc(c.adv1)
		gen_adv_desc(c.adv2)
		gen_adv_desc(c.adv3)
	elseif c.type == "civ" then
		if c.victory then
			c._victory = "$(civ." .. c.victory .. ".desc)"
		end
		if c.advancement then
			c._advancement = "$(civ." .. c.advancement .. ".desc)"
		end
		c._name = "$(card.civ.name.final)"
	end
	gen_marker(c)
end

function card.complete(c)
	if c.type == "tech" then
		return c.adv1 and c.adv1.value and c.adv2 and c.adv2.value and c.adv3 and c.adv3.value
	else
		-- world card check adv3 only
		return c.adv3 and c.adv3.suit
	end
end

function card.test_newcard(args)
	local newcard = #DECK + 1
	local c = new_card {
		_id = nil,
		type = args.type or "blank",
		era = args.era or HISTORY.era,
		value = args.value or 1,
		suit = args.suit or actions[1],
		sector = args.sector or 11,
	}
	if c.type == "civ" then
		c.tech = args.tech
		c.world = args.world
		c.victory = args.victory
		c.advancement = args.advancement
	end
	if args.marker then
		c.value = tonumber(args.marker:sub(1,1))
		c.suit = args.marker:sub(2,2)
	end
	loadsave.sync_card(newcard, c)
	c._id = newcard
	local def
	if c.type == "tech" then
		def = "S"
		c.sector = nil
	end
	if args.adv then
		if type(args.adv) == "string" then
			c.adv1 = convert_adv(args.adv)
		else
			c.adv1 = convert_adv(args.adv[1] or def)
			c.adv2 = convert_adv(args.adv[2] or def)
			c.adv3 = convert_adv(args.adv[3] or def)
		end
	end
	
	if args.name then
		c.name = args.name
	else
		local f = genname[c.type]
		if f then
			f(c)
		end
	end
	card.gen_desc(c)
	DECK[newcard] = c
	return c
end

function card.card(where, index)
	local pile = GAME[where]
	if pile then
		local c = pile[index]
		return DECK[c]
	end
end

function card.pile(where, r)
	r = r or {}
	local n = #r
	local pile = GAME[where]
	if pile then
		for i = 1, #pile do
			r[n+i] = DECK[pile[i]]
		end
	end
	return r
end

function card.upkeep(c)
	return GAME.upkeep[c._id] or 0
end

-- todo : don't inject into advancement
function advancement._upkeep_full()
	local n = #GAME.homeworld
	for k,v in pairs(GAME.upkeep) do
		if v ~= UPKEEP_LIMIT then
			return
		end
		n = n - 1
	end
	-- all homeworld cards full
	return n == 0
end

function card.upkeep_change(c, def)
	local n = GAME.upkeep[c._id] or 0
	local n2 = n
	if def then
		n2 = n2 + def
	else
		n2 = 0
	end
	if n2 < 0 then
		n2 = 0
	elseif n2 > UPKEEP_LIMIT then
		n2 = UPKEEP_LIMIT
	end
	if n == n2 then
		return
	else
		if n2 > 0 then
			c._upkeep = UPKEEP_LOGO:rep(n2)
		else
			n2 = nil
			c._upkeep = nil
		end
		GAME.upkeep[c._id] = n2
		vcard.flush(c)
	end
end

function card.sector(sec)
	local r = {}
	local homeworld = DECK[GAME.homeworld[1]]
	if homeworld.sector == sec then
		r[1] = homeworld
	end
	for _, id in ipairs(GAME.colony) do
		local c = DECK[id] 
		if c.sector == sec then
			r[#r+1] = c
		end
	end
	if #r > 0 then
		return r
	end
end

function card.check_only_sector(sec)
	local homeworld = DECK[GAME.homeworld[1]]
	if homeworld.sector ~= sec then
		return false
	end
	for _, id in ipairs(GAME.colony) do
		local c = DECK[id] 
		if c.sector ~= sec then
			return false
		end
	end
	return true	
end

function card.has_player_world(sec)
	local homeworld = DECK[GAME.homeworld[1]]
	if homeworld.sector == sec then
		return true
	end
	for _, id in ipairs(GAME.colony) do
		local c = DECK[id] 
		if c.sector == sec then
			return true
		end
	end
	return false
end

local function get_adv_suit(c, key, r)
	local adv = c[key]
	if adv == nil then
		return
	end
	if adv.value and adv.suit then
		r[adv.suit] = true
	end
end

function card.adv_suits(c)
	local r = {}
	get_adv_suit(c, "adv1", r)
	get_adv_suit(c, "adv2", r)
	get_adv_suit(c, "adv3", r)
	return r
end

function card.find_suit(where, suits, r)
	r = r or {}
	local area = GAME[where]
	for i, id in ipairs(area) do
		local c = DECK[id]
		if suits[c.suit] then
			r[c] = true
		end
	end
	return r
end

local function match_adv_suit(c, key, suits, r)
	local adv = c[key]
	if adv == nil then
		return
	end
	if adv.value and adv.suit then
		if suits[adv.suit] then
			r[c] = true
		end
	end
end

--检查母星维护方块 并检查挑战花色
function card.find_upkeep(suits, r)
	r = r or {}
	for i, id in ipairs(GAME.homeworld) do
		local upkeep = GAME.upkeep[id] or 0
		if upkeep > 0 then
			local c = DECK[id]
			match_adv_suit(c, "adv1", suits, r)
			match_adv_suit(c, "adv2", suits, r)
			match_adv_suit(c, "adv3", suits, r)
		end
	end
	return r
end

local suit_info = util.cache(function(suit)
	return "$(suit."..ui.suit[suit]..")"
end)

function card.suit_info(obj)
	return suit_info[obj.suit]
end

local function suit_text(s)
	if s == nil or s.value == nil then
		return ""
	else
		return suit_info[s.suit]
	end
end

local function unique(t, obj)
	if t[obj] == nil then
		t[obj] = true
		t[#t+1] = obj
	end
end

function card.payment_text(c)
	local markers = {}
	unique(markers, suit_text(c.adv1))
	unique(markers, suit_text(c.adv2))
	unique(markers, suit_text(c.adv3))
	
	return table.concat(markers)
end

function card.has_advancement(c, from, adv_name, focus)
	if from == "hand" and (c.type ~= "tech" or not card.complete(c)) then
		return
	end
	local count = 0
	for i = 1, 3 do
		local adv = c["adv"..i]
		if adv and adv.value then
			if advancement.name(adv.suit, adv.value) == adv_name then
				count = count + 1
			end
		end
	end
	if count > 0 then
		return count
	end
end

function card.chosen(c)
	local n = 0
	for i = 1, 3 do
		local adv = c["adv"..i]
		if adv and adv.chosen then
			n = n + 1
		end
	end
	return n
end

function card.settling(c)
	if not c then
		return DECK[GAME.settling]
	else
		local id = c._id
		assert(c.type == "world")
		GAME.settling = id
		return c
	end
end

function card.find_uncomplete(where, r)
	local n = 1
	while true do
		local c = card.card(where, n)
		if not c then
			return r
		end
		if not card.complete(c) then
			r[c] = true
		end
		n = n + 1
	end
end

local function collect_suits(adv, suits)
	if adv == nil then
		return
	end
	suits[adv.suit] = (suits[adv.suit] or 0) + 1
end

function card.collect_suits(c, suits)
	if not card.complete(c) then
		return suits
	end
	collect_suits(c.adv1, suits)
	collect_suits(c.adv2, suits)
	collect_suits(c.adv3, suits)
	return suits
end

return card
