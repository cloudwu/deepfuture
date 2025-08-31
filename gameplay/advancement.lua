local rules = require "core.rules".advancement
local util = require "core.util"

global pairs, tonumber, print

local advancement = {}

local function find(suit, value)
	for k,v in pairs(rules) do
		if v.suit == suit and v.value == value then
			return v, k
		end
	end
end

local function suit_value(key)
	local suit = key:sub(1,1)
	local value = tonumber(key:sub(2,2))
	return suit, value
end

local stage_cache = util.cache(function(key)
	return find(suit_value(key)).stage
end)

function advancement.stage(suit, value)
	return stage_cache[suit..value]
end

local name_cache = util.cache(function (key)
	local _, name = find(suit_value(key))
	return name
end)

function advancement.name(suit, value)
	return name_cache[suit..value]
end

function advancement.info(adv, what)
	return "$(adv."..adv.."."..what..")"
end

function advancement.config(name)
	return rules[name]
end

return advancement
