local flow = require "core.flow"
local mouse = require "core.mouse"
local vdesktop = require "visual.desktop"
local card = require "gameplay.card"
local util = require "core.util"
local vtips = require "visual.tips" .layer "desc"

global print, pairs, ipairs, type, print_r

local M = {}

local function level2_menu(list)
	local r = {}
	local from = list[list[1]]
	for i = 2, #list do
		r["menu2" .. (from + i - 2)] = list[i]
	end
	return r
end

local buttons_cache = util.cache(function (list)
	local index = list[list[1]]
	if type(index) == "number" then
		return level2_menu(list)
	end
	local r = {}
	for i, name in ipairs(list) do
		if type(name) == "table" then
			-- level 2 menu
			local key = name[1]
			name[key] = i
			r["menu" .. i] = key
			r[key] = name
		else
			r["menu" .. i] = name
		end
	end
	return r
end)

local function button_enable(buttons, enable)
	if enable then
		for k, what in pairs(buttons) do
			local name = what
			if type(what) == "table" then
				name = what[1]
			end
			vdesktop.button_enable(k, {
				text = "button.menu." .. name,
			})
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

function action.restart_confirm()
	return "RESTART"
end

local desc = {}

local function wait_for_return(buttons)
	button_enable(buttons, true)
	vdesktop.describe(desc)
	local r
	local focus_state = {}
	local level2_key
	local function menu_key(btn)
		if level2_key then
			return buttons[btn] or buttons_cache[buttons[level2_key]][btn]
		else
			return buttons[btn]
		end
	end
	local function enable_level1(flag)
		for menu_key, button_key in pairs(buttons) do
			if type(button_key) ~= "table" and button_key ~= level2_key then
				vdesktop.button_enable(menu_key, {
					text = "button.menu." .. button_key,
					disable = not flag,
				})
			end
		end
	end
	local function level2(list)
		local buttons2 = buttons_cache[list]
		if level2_key then
			-- close
			enable_level1(true)
			button_enable(buttons2)
			level2_key = nil
		else
			-- open
			level2_key = list[1]
			enable_level1(false)
			button_enable(buttons2, true)
		end
	end
	while true do
		if mouse.get(focus_state) then
			local menu = menu_key(focus_state.active)
			if menu then
				vtips.set("tips.menu."..menu)
			else
				vtips.set()
			end
		end
		local c, btn = mouse.click(focus_state, "left")
		if c then
			local click = menu_key(btn)
			if click then
				local submenu = buttons[click]
				if submenu then
					-- level 2 menu
					level2(submenu)
				else
					r = action[click]()
					break
				end
			end
		end
		flow.sleep(0)
	end
	button_enable(buttons, false)
	vdesktop.describe(false)
	return r
end

return function (button_list)
	vtips.push()
	local r = wait_for_return(buttons_cache[button_list])
	vtips.pop()
	return r
end
