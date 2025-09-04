local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local rules = require "core.rules".phase
local card = require "gameplay.card"
local class = require "core.class"
local track = require "gameplay.track"
local loadsave = require "core.loadsave"
local sync = require "gameplay.sync"

global none

local DEFAULT_DRAW <const> = rules.power.draw
local ACTION_TEXT <const> = "[blue]$(POWER)[n]"

local adv_focus = {}

function adv_focus.labor()
	track.focus("S", true)
end

function adv_focus.empire()
	track.focus("M", true)
end

function adv_focus.devices()
	track.focus("C", true)
end

local power_adv = {}

local function draw_card(advs)
	local c = card.draw_hand()
	if c then
		advs:add(c, "hand")
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		flow.sleep(5)
	end
end

function power_adv.industry(advs)
	advs:discard_one_card("action", "industry", ACTION_TEXT)
	draw_card(advs)
	draw_card(advs)
	advs:update()
end

function power_adv.energy(advs)
	draw_card(advs)
	advs:update()
end

function power_adv.labor()
	track.advance("S", 1)
end

function power_adv.empire()
	track.advance("M", 1)
end

function power_adv.devices()
	track.advance("C", 2)
end

return function(extra, action_name)
	loadsave.sync_game(action_name or "power")
	sync()
	vdesktop.set_text("phase", { text = "$(phase.action)" })
	local phase_desc = { extra = ACTION_TEXT }
	if extra then
		phase_desc.extra = extra .. phase_desc.extra
	end
	vdesktop.set_text("phase", phase_desc )
	-- default behaviour : draw cards
	for i = 1, DEFAULT_DRAW do
		local c = card.draw_hand()
		if c then
			vdesktop.add("deck", c)
			vdesktop.transfer("deck", c, "hand")
			flow.sleep(5)
		end
	end
	
	local advs = class.effect "POWER"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"

	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "power",
			adv_focus = adv_focus,
			adv_func = power_adv,
		}
		advs:discard_used_cards()
	end
	
	return "action"
end
