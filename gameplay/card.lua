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

function card.init_draw()
	local init = { _type = "list" }
	local n = 1
	for id, card in ipairs(DECK) do
		if card.type ~= "deleted" then
			init[n] = id; n = n + 1
		end
	end
	DRAW = persist.init("draw", init)
end

return card
