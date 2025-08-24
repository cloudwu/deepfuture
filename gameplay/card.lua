local persist = require "gameplay.persist"
local math = math
local table = table
local advancement = require "gameplay.advancement"

global tostring, setmetatable, ipairs, pairs, print, print_r, error, assert

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
	return table.remove(draw, 1)
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

function card.nextera()
	HISTORY.era = HISTORY.era + 1
end

function card.pickup(where, card)
	local id = card._id
	local area = GAME[where]
	for i, c in ipairs(area) do
		if c == id then
			table.remove(area, i)
			return
		end
	end
	error ("No card in " .. where)
end

function card.putdown(where, card)
	local id = card._id
	local area = GAME[where]
	for i, c in ipairs(area) do
		if c == id then
			return
		end
	end
	area[#area+1] = id
end

function card.drophand()
	table.move(GAME.hand, 1, #GAME.hand, #GAME.discard + 1, GAME.discard)
	GAME.hand = {}
end

function card.discard(card)
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
		adv._name = ""
		adv._stage = ""
		adv._desc = ""
	else
		local prefix = "$(adv."..advancement.name(adv.suit, adv.value).."."
		adv._suit = "$(suit."..adv.suit..")"
		adv._name = prefix .. "name)." .. adv.era
		local stage = advancement.stage(adv.suit, adv.value)
		adv._stage = "[[$(".. stage .. ")]"
		adv._stage_focus = "[blue]" .. adv._stage .. "[n]"
		adv._stage_normal = adv._stage
		adv._desc = prefix .. "desc)"
	end
end

local function get_stage(c, n)
	local adv = c["adv" .. n]
	if adv == nil or adv.value == nil then
		return
	end
	return advancement.stage(adv.suit, adv.value)
end

function card.stage(pile, index, n)
	local card_id = GAME[pile][index]
	if card_id == nil then
		return
	end
	local c = DECK[card_id]
	if pile == "hand" then
		if c.type == "tech" and card.complete(c) then
			return get_stage(c, n), c
		end
	else
		return get_stage(c, n), c
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

local function find_advancements_from(result, stage_name, region)
	local n = card.count(region)
	for i = 1, n do
		for j = 1, 3 do
			local stage, c = card.stage(region, i, j)
			if stage == stage_name then
				local adv_index = "adv" .. j
				local adv = c[adv_index]
				local obj = {
					index = j,
					name = advancement.name(adv.suit, adv.value),
					card = c,
				}
				result[#result+1] = obj
			end
		end
	end
end

function card.find_stage(stage_name, regions)
	local r = {}
	for _, region in ipairs(regions) do
		find_advancements_from(r, stage_name, region)
	end
	
	return r
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

-- todo: load deck

return card
