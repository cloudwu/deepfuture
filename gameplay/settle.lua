local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local rules = require "core.rules".phase
local card = require "gameplay.card"
local class = require "core.class"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vcard = require "visual.card"
local vtips = require "visual.tips".layer "hud"
local focus = require "core.focus"

global next, pairs, print

local adv_focus = {}

function adv_focus.leisure()
	track.focus("C", true)
end

function adv_focus.medicine()
	track.focus("S", true)
end

function adv_focus.ecology()
	track.focus("X", true)
end

local settle_adv = {}

function settle_adv.leisure()
	track.advance("C", 2)
end

function settle_adv.government()
	-- todo : add adv to settling
end

function settle_adv.society()
	-- todo : mask discard card (new world)
end

function settle_adv.medicine()
	track.advance("S", 1)
end

function settle_adv.ecology()
	track.advance("X", 1)
end

local function settling(advs)
	local newcard = card.settling()
	if newcard then
		-- already choose (test mode or load)
		vdesktop.add("deck", newcard)
		vdesktop.transfer("deck", newcard, "float")
		flow.sleep(1)
		return newcard
	end
	-- active society advancement
	local n = advs:update { society = true }
	
	local cards = {}
	local blank_cards = {}
	local n = 1
	local has_world = false
	while true do
		local c = card.card("hand",n)
		if not c then
			break
		end
		n = n + 1
		if c.type == "world" then
			has_world = true
			if map.player_ctrl(c.sector) then
				cards[c] = true
			end
		elseif not has_world and c.type == "blank" then
			blank_cards[#blank_cards+1] = c
		end
	end
	local allow_new_world
	if not has_world then
		-- no world card in hand
		if next(cards) == nil then
			local n = #blank_cards
			if n == 0 then
				-- no blank card in hand, too.
				-- allow settle new world from draw pile
				allow_new_world = true
			else
				-- blank cards can use
				for i = 1, n do
					cards[blank_cards[i]] = true
				end
			end
		end
	end

	-- add neutral worlds
	n = 1
	while true do
		local c = card.card("neutral",n)
		if not c then
			break
		end
		n = n + 1
		if map.player_ctrl(c.sector) then
			cards[c] = true
		end
	end
	
	local function set_mask(enable)
		if allow_new_world then
			vdesktop.draw_pile_focus(enable)
		end
		for c in pairs(cards) do
			vcard.mask(c, enable)
		end
	end
	
	set_mask(true)
	
	local desc = {}
	local focus_state = {}
	
	while true do
		if focus.get(focus_state) then
			local c = focus_state.object
			if cards[c] then
				-- choose card
				if c.type == "world" then
					desc.world = c
					if focus_state.active == "neutral" then
						vtips.set("tips.settle.capture", desc)
					else
						vtips.set("tips.settle.hand", desc)
					end
				else
					vtips.set "tips.settle.blank"
				end
			elseif focus_state.active == "discard" then
				vtips.set "tips.settle.newworld"
			elseif advs:can_use(c) then
				vtips.set "tips.settle.society"
			else
				vtips.set "tips.settle.advice"
			end
		elseif focus_state.lost then
			vtips.set()
		end
		-- todo : click to choose
		flow.sleep(0)
	end
end

return function()
	vdesktop.set_text("phase", { extra = "[blue]$(SETTLE)[n]" } )
	-- default behaviour : choose settle world
	
	local advs = class.effect "SETTLE"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"
	
	local newworld = settling(advs)
	card.settling(newworld)

	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "settle",
			adv_focus = adv_focus,
			adv_func = settle_adv,
		}
		advs:discard_used_cards()
	end
	
	card.putdown("colony", newworld)
	vdesktop.transfer("float", newworld, "colony")
	flow.sleep(5)
end
