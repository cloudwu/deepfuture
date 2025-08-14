local persist = require "gameplay.persist"

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
	"S", "M", "H", "K", "H", "F"
}

local DECK

function card.init_deck()
	local init = { _type = "list" }
	local id = 1
	for i = 1, 6 do
		for j = 1, 6 do
			local card = {
				value = i,
				suit = actions[j],
				type = "blank",
			}
			init[id] = card; id = id + 1
		end
	end
	DECK = persist.init("deck", init)
end

local DRAW
local DISCARD
local HAND
local CONTEXT

function card.setup()
	local init = { _type = "list" }
	local n = 1
	for id, card in ipairs(DECK) do
		if card.type ~= "deleted" then
			init[n] = id; n = n + 1
		end
	end
	DRAW = persist.init("draw", init)
	DISCARD = persist.init("discard", { _type = "list" })
	HAND = persist.init("hand", { _type = "list" })
	CONTEXT = persist.init("context", {
		seen = 0,	-- seen cards of drawpile
	})
end

local function draw_card()
	local n = #DRAW
	if n == 0 then
		n = #DISCARD
		if n == 0 then
			-- discard pile is empty, draw fail
			return
		end
		-- swap draw pile and discard pile
		DRAW, DISCARD = DISCARD, DRAW
	end
	local seen = CONTEXT.seen
	if seen == 0 then
		local idx = math.random(n)
		local card = DRAW[idx]
		DRAW[idx] = DRAW[n]
		DRAW[n] = nil
		return card
	end
	CONTEXT.seen = seen - 1
	return table.remove(DRAW, 1)
end

function card.draw_hand()
	local card_id = draw_card()
	if card_id == nil then
		return
	end
	HAND[#HAND+1] = card_id
	return DECK[card_id]
end

function card.draw_discard()
	local card_id = draw_card()
	if card_id == nil then
		return
	end
	DISCARD[#DISCARD+1] = card_id
	return DECK[card_id]
end

function card.generate_newcard()
	assert(CONTEXT._temporary == nil)
	local card1 = draw_card()
	local card2 = draw_card()
	if not (card1 and card2) then
		-- no 2 cards
		return
	end
	local n = #DISCARD
	DISCARD[n+1] = card1
	DISCARD[n+2] = card2

	card1 = DECK[card1]
	card2 = DECK[card2]
	
	local card = {
		value = card1.value,
		suit = card2.suit,
		type = "blank",
	}

	local newcard = #DECK + 1
	CONTEXT._temporary = newcard
	
	DECK[newcard] = card
	return card, card1, card2
end

function card.discard()
	local card = assert(CONTEXT._temporary)
	CONTEXT._temporary = nil
	DISCARD[#DISCARD + 1] = card
end

return card
