local genname = require "gameplay.name"
local persist = require "gameplay.persist"
local math = math
local table = table
local error = error
local advancement = require "gameplay.advancement"
local rules = require "core.rules".phase
local ui = require "core.rules".ui

global tostring, setmetatable, ipairs, pairs, print, print_r, assert, tonumber, type

local UPKEEP_LIMIT <const> = rules.payment.upkeep_limit
local UPKEEP_LOGO <const> = ui.payment.upkeep
local card = {}

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

local actions = {
	"S", "M", "R", "K", "H", "F"
}

local DECK
local HISTORY

local function gen_marker(obj)
	obj._marker = tostring(obj.value) .. "$(suit." .. obj.suit .. ")"
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
	local init = { _type = "list" }
	local id = 1
	for i = 1, 6 do
		for j = 1, 6 do
			local card = new_card {
				value = i,
				suit = actions[j],
				type = "blank",
				era = 0,
			}
			gen_marker(card)
			init[id] = card; id = id + 1
		end
	end
	DECK = persist.init("deck", init)
	HISTORY = persist.init("history", {
		era = 0
	})
end

local GAME
local areas = { "draw", "discard", "hand", "neutral", "homeworld", "colony" }

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
		game[area] = { _type = "list" }
		local init_func = areas[area]
		if init_func then
			init_func(game[area])
		end
	end
	game.seen = 0 -- seen cards of drawpile
	game.upkeep = {}
	GAME = persist.init("game", game)
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

function card.debug()
	print_r("DRAW", GAME.draw)
	print_r("DISCARD", GAME.discard)
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
		_id = newcard,
		value = card1.value,
		suit = card2.suit,
		type = "blank",
		era = HISTORY.era,
	}
	gen_marker(card)

	DECK[newcard] = card
	return card, card1, card2
end

local function convert_adv(advname)
	local c = advancement.config(advname)
	return {
		suit = c.suit,
		value = c.value,
		era = HISTORY.era,
	}
end

function card.nextera()
	HISTORY.era = HISTORY.era + 1
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
			local id = table.remove(area, i)
			return DECK[id]
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
		adv._suit = "$(suit."..adv.suit..")"
		adv._name = nil
		adv._stage = nil
		adv._desc = nil
	else
		local adv_name = advancement.name(adv.suit, adv.value)
		local prefix = "$(adv."..advancement.name(adv.suit, adv.value).."."
		adv._suit = "$(suit."..adv.suit..")"
		adv._name = advancement.info(adv_name, "name").. "." .. adv.era
		adv._desc = advancement.info(adv_name, "desc")
		local stage = advancement.stage(adv.suit, adv.value)
		adv._stage = "[[$(".. stage .. ")]"
		adv._stage_focus = "[blue]" .. adv._stage .. "[n]"
		adv._stage_use = "[40000000]" .. adv._stage .. "[n]"
		adv._stage_normal = adv._stage
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
	end
end

function card.complete(c)
	return c.adv1 and c.adv1.value and c.adv2 and c.adv2.value and c.adv3 and c.adv3.value
end

local check_adv = {}

function check_adv.computation()
	return GAME.draw, GAME.discard
end

function check_adv.history()
	return GAME.draw, GAME.seen
end

function check_adv.economy()
	return GAME.draw, GAME.discard
end

function card.check_adv(adv_name)
	local f = check_adv[adv_name]
	if f then
		return advancement.check(adv_name, f())
	else
		return advancement.check(adv_name)
	end
end

function card.test_newcard(args)
	local newcard = #DECK + 1
	local card = new_card {
		_id = newcard,
		type = args.type or "blank",
		era = args.era or HISTORY.era,
		value = 1,
		suit = actions[1],
		sector = args.sector or 11,
	}
	if args.marker then
		card.value = tonumber(args.marker:sub(1,1))
		card.suit = args.marker:sub(2,2)
	end
	gen_marker(card)
	if args.adv then
		if type(args.adv) == "string" then
			card.adv1 = convert_adv(args.adv)
		else
			card.adv1 = convert_adv(args.adv[1])
			card.adv2 = convert_adv(args.adv[2])
			card.adv3 = convert_adv(args.adv[3])
		end
		gen_adv_desc(card.adv1)
		gen_adv_desc(card.adv2)
		gen_adv_desc(card.adv3)
	end
	
	if args.name then
		card.name = args.name
	else
		local f = genname[card.type]
		if f then
			f(card)
		end
	end
	DECK[newcard] = card
	return card
end

function card.card(where, index)
	local c = GAME[where][index]
	return DECK[c]
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
		GAME.upkeep[c._id] = n2
		if n2 > 0 then
			c._upkeep = UPKEEP_LOGO:rep(n2)
		else
			c._upkeep = nil
		end
		return n2
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

-- todo: load deck

return card
