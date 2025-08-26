local advancement = require "gameplay.advancement"
local vcard = require "visual.card"
local card = require "gameplay.card"
local util = require "core.util"
local class = require "core.class"

global setmetatable, pairs, assert, print

local effect = class.container "effect"

function effect:add(c, from)
	if from == "hand" and (c.type ~= "tech" or not card.complete(c)) then
		return
	end
	assert(self[c] == nil)
	local obj = {}
	self[c] = obj
	local stage = self[false]
	for i = 1, 3 do
		local adv = c["adv"..i]
		if adv and adv.value then
			if advancement.stage(adv.suit, adv.value) == stage then
				obj[i] = {
					name = advancement.name(adv.suit, adv.value),
					enable = true,
					use = false,
				}
			end
		else
			obj[i] = false
		end
	end
end

function effect:add_pile(from)
	local n = 1
	while true do
		local c = card.card(from, n)
		if c == nil then
			return
		end
		self:add(c, from)
		n = n + 1
	end
end

function effect:remove(c)
	local obj = self[c]
	self[c] = nil
	vcard.mask(c)
	for i = 1, 3 do
		if obj[i] then
			vcard.focus_adv(c, i)
		end
	end
end

function effect:focus(c)
	local obj = self[c]
	if not obj then
		return
	end
	local focus = obj.focus
	if not focus then
		return
	end
	return obj[focus].name
end

function effect:update()
	local check = util.cache(card.check_adv)
	local tmp = {}
	local n = 0
	for c, adv in pairs(self) do
		tmp[c] = false
		for index = 1, 3 do
			local obj = adv[index]
			if obj then
				if obj.use then
					vcard.focus_adv(c, index, false)
					if adv.focus == index then
						adv.focus = nil
					end
				else
					local enable = check[obj.name]
					obj.enable = enable
					if enable then
						n = n + 1
						tmp[c] = index
					end
					vcard.focus_adv(c, index, nil)
				end
			end
		end
	end
	
	for c, index in pairs(tmp) do
		if index then
			vcard.mask(c, true)
			self[c].focus = index
			vcard.focus_adv(c, index, true)
		else
			vcard.mask(c)
		end
	end
	return n
end

local order <const> = {
	{ 2, 3 },	-- next 1
	{ 3, 1 },	-- next 2
	{ 1, 2 },	-- next 3
}

local function next_adv(self, c)
	local obj = self[c]
	local focus = obj.focus
	for i = 1, 2 do
		local idx = order[focus][i]
		local n = obj[idx]
		if n and n.enable then
			return idx
		end
	end
end

function effect:use(c)
	local obj = self[c]
	local current = obj[obj.focus]
	current.use = true
	current.enable = false
	vcard.focus_adv(c, obj.focus, false)
	local n = next_adv(self, c)
	if n then
		obj.focus = n
		vcard.focus_adv(c, n, true)
	else
		vcard.mask(c)
		obj.focus = nil
	end
end

local function next_unique(self, c)
	local obj = self[c]
	local focus = obj.focus
	local name = obj[focus].name
	for i = 1, 2 do
		local idx = order[focus][i]
		local n = obj[idx]
		if n and n.enable and n.name ~= name then
			return idx
		end
	end
end

function effect:nextadv(c, switch)
	local n = next_unique(self, c)
	if n then
		if switch then
			vcard.focus_adv(c, self[c].focus, nil)
			vcard.focus_adv(c, n, true)
			self[c].focus = n
		end
		return self[c][n].name
	end
end

function effect:reset()
	for c in pairs(self) do
		vcard.mask(c)
		vcard.focus_adv(c, 1)
		vcard.focus_adv(c, 2)
		vcard.focus_adv(c, 3)
	end
end

function effect:used_cards()
	local cards = {}
	for c, obj in pairs(self) do
		for i = 1, 3 do
			local adv = obj[i]
			if adv and adv.use then
				cards[#cards+1] = c
			end
		end
	end
	return cards
end

function effect:is_used(c)
	local obj = self[c]
	if not obj then
		return
	end
	for i = 1, 3 do
		local adv = obj[i]
		if adv and adv.use then
			return true
		end
	end
end

function effect:can_use(c)
	local obj = self[c]
	if obj == nil then
		return
	end
	return self[c].focus
end

function class.effect(action)
	return effect {
		[false] = action,
	}
end
