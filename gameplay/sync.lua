local card = require "gameplay.card"
local vdesktop = require "visual.desktop"
local flow = require "core.flow"
local track = require "gameplay.track"
local map = require "gameplay.map"
local table = table

global ipairs, pairs, print

local function add_challenges(cp)
	for i = 1, #cp do
		local c = cp[i]
		if c then
			-- add back to colony
			-- todo :  same code in payment.lua
			local back = { type = "back", text = "$(card.challenge)", _challenge = c }
			c._back = back
			vdesktop.add("deck", back)
			vdesktop.transfer("deck", back, "colony")
			flow.sleep(5)
		end
	end
end

local function sync(where)
	local p = card.pile(where)
	local diff = vdesktop.sync(where, p)
	if not diff then
		if where == "colony" then
			-- load file
			add_challenges(card.pile "challenge")
		end
		return
	end
	if where == "colony" then
		-- challenge cards are in colony pile
		local challenge = {}
		local n = 1
		while true do
			local c = diff.discard[n]
			if c == nil then
				break
			end
			if c._challenge then
				challenge[c._challenge] = c
				table.remove(diff.discard, n)
			else
				n = n + 1
			end
		end
		local cp = card.pile "challenge"
		for i = 1, #cp do
			local c = cp[i]
			if challenge[c] then
				-- exist in colony
				challenge[c] = nil
				cp[i] = false
			end
		end
		for c, back in pairs(challenge) do
			vdesktop.transfer("colony", back, "deck")
			flow.sleep(5)
		end
		add_challenges(cp)
	end
	for _, c in ipairs(diff.discard) do
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
	for _, c in ipairs(diff.draw) do
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, where)
		flow.sleep(5)
	end
end

return function()
	flow.sleep(1)	-- wait for transfer
	sync "hand"
	sync "homeworld"
	sync "neutral"
	sync "colony"
	
	for i = 1, card.count "colony" do
		local c = card.card("colony", i)
		map.settle(c.sector)
	end
	local homeworld = card.card ("homeworld", 1)
	if homeworld then	-- no homeworld in setup phase 
		map.settle(homeworld)
	end
	
	track.sync()
	map.sync()

	vdesktop.set_text("turn", {
		turn = card.turn(),
	})
end
