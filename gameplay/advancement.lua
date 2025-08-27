local rules = require "core.rules".advancement
local util = require "core.util"
local track = require "gameplay.track"
local map = require "gameplay.map"

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

local adv_check = {}

function adv_check.computation(draw_pile, discard_pile)
	local n = #draw_pile + #discard_pile
	return n > 0
end

function adv_check.art()
	return track.check("C", 1)
end

local function check_any_track()
	return track.check("C", -1) or track.check("M", -1) or track.check("S", -1) or track.check("X", -1)
end

function adv_check.infrastructure()
	-- inject from core.card
	if advancement._upkeep_full() then
		return false
	end
	return check_any_track()
end

function adv_check.history(draw_pile, seen)
	return #draw_pile - seen > 0
end

function adv_check.economy(draw_pile, discard_pile)
	local n = #draw_pile + #discard_pile
	return check_any_track() and n > 0
end

function adv_check.exploration()
	local r = map.can_move()
	return r
end

function advancement.check(what, ...)
	return adv_check[what](...)
end

return advancement
