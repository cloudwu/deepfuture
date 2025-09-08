local card = require "gameplay.card"
local vdesktop = require "visual.desktop"
local mouse = require "core.mouse"
local flow = require "core.flow"
local vtips = require "visual.tips".layer "hud"
local track = require "gameplay.track"
local vcard = require "visual.card"
local map = require "core.mouse"

global assert, ipairs, pairs

local desktop = {}

local function wait_moving(where, c)
	repeat
		flow.sleep(1)
	until not vdesktop.moving(where, c)
end

function desktop.move_to_neutral(c, from)
	card.upkeep_change(c)	-- clear upkeep
	vdesktop.transfer(from, c, "neutral")
	local last = card.find_value("neutral", c.value)
	if last then
		last = card.pickup("neutral", last)
		card.discard(last)
		vdesktop.transfer("neutral", last, "deck")
	end
	card.putdown("neutral", c)
	wait_moving("neutral", c)
end

function desktop.relocate_homeworld(homeworld)
	vtips.set()
	desktop.move_to_neutral(homeworld, "homeworld")
	local colony = card.pile "colony"
	if #colony == 0 then
		return
	end
	for _, c in ipairs(colony) do
		vcard.mask(c, true)
	end
	vdesktop.set_text("phase", { extra = "$(tips.challenge.relocate)" })
	local focus_state = {}
	local new_homeworld
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "colony" then
				vtips.set "tips.homeworld.set"
			elseif focus_state.object then
				vtips.set "tips.homeworld.invalid"
			else
				vtips.set()
			end
		end
		local sec, region = mouse.click(focus_state, "left")
		if sec and region == "colony" then
			new_homeworld = card.pickup("colony", sec)
			break
		end
		flow.sleep(0)
	end
	for _, c in ipairs(colony) do
		vcard.mask(c)
	end
	card.putdown("homeworld", new_homeworld)
	vdesktop.transfer("colony", new_homeworld, "homeworld")
	vtips.set()
	flow.sleep(5)
	return true
end

function desktop.check_lost(lost)
	if not lost then
		return track.loss()
	end
	local colony_sector = {}
	local n = 1
	while true do
		local c = card.card("colony", n)
		if c == nil then
			break
		end
		n = n + 1
		local list = colony_sector[c.sector] or {}
		colony_sector[c.sector] = list
		list[#list+1] = c
	end
	-- discard colony
	for sector in pairs(lost) do
		local list = colony_sector[sector]
		if list then
			for _, c in ipairs(list) do
				c = card.pickup("colony", c)
				card.discard(c)
				vdesktop.transfer("colony", c , "deck")
				flow.sleep(5)
			end
		end
	end
	local homeworld = card.card("homeworld", 1)
	assert(homeworld and homeworld.type == "world")
	if lost[homeworld.sector] then
		-- lost homeworld
		local c = card.pickup("homeworld", homeworld)
		if not desktop.relocate_homeworld(c) then
			vtips.set()
			return true
		end
	end
	return track.loss()
end

return desktop