local card = require "gameplay.card"
local track = require "gameplay.track"
local map = require "gameplay.map"
local rules_track = require "core.rules".track
local rules_vic = require "core.rules".victory
local persist = require "gameplay.persist"

global string, tostring, print, pairs, type, setmetatable, ipairs

local victory = {}

-- homeworld must exist and complete
local function check_homeworld()
    local homeworld = card.card("homeworld", 1)
    return homeworld and homeworld.type == "world" and card.complete(homeworld)
end

-- count complete tech cards
local function count_complete_techs()
    local count = 0
    local n = 2	-- skip homeworld
    
    while true do
        local c = card.card("homeworld", n)
        if not c then
            break
        end
        if card.complete(c) then
            count = count + 1
        end
        n = n + 1
    end

    return count
end

local checker = {}; checker.__index = checker

function checker:territory()
    local sector_count = 0
    for _ in pairs(self) do
        sector_count = sector_count + 1
    end
	return sector_count >= rules_vic.condition.sectors
end

function checker:population()
	local people = 0
    for _, cubes in pairs(self) do
        people = people + cubes
    end
	return people >= rules_vic.condition.people
end

function checker:culture()
	return track.win "C"
end

function checker:might()
	return track.win "M"
end

function checker:stability()
	return track.win "S"
end

function checker:xeno()
	return track.win "X"
end

function victory.checker()
	local obj = map.territory()
	if obj == nil then
		return
	end
	return setmetatable(obj, checker)
end

local MAX_NEED_COLONY <const> = rules_vic.condition.colony

function victory.check()
    if not check_homeworld() then
		return
	end
	
	if count_complete_techs() < rules_vic.condition.tech then
		return
	end
	
	local colony_count = card.count "colony"
	local need_colony = map.wonder_number()
	if need_colony > MAX_NEED_COLONY then
		need_colony = MAX_NEED_COLONY
	end
	if colony_count < need_colony then
		return
	end
	
	local checker = victory.checker()
	if checker then
		for _, vic in ipairs(rules_vic.name) do
			if checker[vic](checker) then
				return vic
			end
		end
	end
end

return victory
