local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local mouse = require "core.mouse"
local card = require "gameplay.card"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"
local track = require "gameplay.track"
local map = require "gameplay.map"

return function()
	loadsave.sync_game "loss"
	sync()
	
	local reason
	local homeworld = card.card("homeworld", 1)
	if not homeworld or homeworld.type ~= "world" then
		reason = "homeworld"
	else
		reason = track.loss()
	end
	
	reason = reason or "unknown"
	
	vdesktop.set_text("phase", {
		text = "$(phase.end)",
		extra = "$(tips.end."..reason..")"
	})
	local button = {
		text = "button.restart",
	}	
	vdesktop.button_enable("button1", button)
	local focus_state = {}
	while true do
		mouse.get(focus_state)
		local c , btn = mouse.click(focus_state, "left")
		if btn == "button1" then
			break
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	card.next_turn()
	vdesktop.set_text("phase", { extra = false })
	
	return flow.state.nextgame
end
