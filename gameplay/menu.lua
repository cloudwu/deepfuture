local flow = require "core.flow"
local mouse = require "core.mouse"
local vdesktop = require "visual.desktop"
local card = require "gameplay.card"

global print, pairs

local M = {}

local buttons = {
	menu1 = "returngame",
	menu2 = "restart",
}

local function button_enable(enable)
	if enable then
		for k, what in pairs(buttons) do
			vdesktop.button_enable(k, { text = "button.menu." .. what })	
		end
	else
		for k, what in pairs(buttons) do
			vdesktop.button_enable(k)	
		end
	end
end

local action = {}

function action.returngame()
	return
end

function action.restart()
	return "RESTART"
end

local function wait_for_return(desc)
	button_enable(true)
	vdesktop.describe(desc)
	local r
	local focus_state = {}
	while true do
		mouse.get(focus_state)
		local c, btn = mouse.click(focus_state, "left")
		if c and buttons[btn] then
			r = action[buttons[btn]]()
			break
		end
		flow.sleep(0)
	end
	button_enable(false)
	vdesktop.describe(false)
	return r
end

return function ()
	return wait_for_return {}
end
