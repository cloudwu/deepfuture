local card = require "gameplay.card"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local flow = require "core.flow"
local track = require "gameplay.track"
local map = require "gameplay.map"
local table = table

global ipairs, pairs, print, string, type, assert

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
		for _, c in ipairs(p) do
			if c.type == "tech" or c.type == "world" then
				card.gen_desc(c)
				vcard.flush(c)
			end
		end
		if where == "colony" then
			-- load file
			add_challenges(card.pile "challenge")
		end
		return
	end
	local cp
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
		cp = card.pile "challenge"
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
	end
	for _, c in ipairs(diff.discard) do
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
	for _, c in ipairs(diff.draw) do
		if c.type == "tech" or c.type == "world" then
			card.gen_desc(c)
			vcard.flush(c)
		end
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, where)
		flow.sleep(5)
	end
	if cp then
		add_challenges(cp)
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
		assert(c.type == "world")
		map.settle(c.sector)
	end
	local homeworld = card.card ("homeworld", 1)
	if homeworld then	-- no homeworld in setup phase 
		map.settle(homeworld.sector)
	end
	
	track.sync()
	map.sync()

	vdesktop.set_text("turn", {
		turn = card.turn(),
	})
end
