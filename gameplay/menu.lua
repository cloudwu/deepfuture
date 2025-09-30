local flow = require "core.flow"
local mouse = require "core.mouse"
local vdesktop = require "visual.desktop"
local card = require "gameplay.card"
local util = require "core.util"
local vtips = require "visual.tips" .layer "desc"
local language = require "core.language"

global print, pairs, ipairs, type, print_r, setmetatable

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

local action = {}

function action.returngame()
	return
end

function action.restart_confirm()
	return "RESTART"
end

function action.startmenu()
	return "STARTMENU"
end

function action.erasegame_confirm()
	card.cleanall()
	-- todo: erase game
	return "STARTMENU"
end

function action.credits()
	return flow.state.credits
end

function action.lang_select(button_list, v)
	button_list.language.name = v.name
	language.switch_flush(v.lang, vdesktop)
end

function action.profile_select(button_list, v)
	card.profile(v.profile, v.savefile)
	return flow.state.load
end

function action.exit()
	return flow.state.exit
end

function action.manual()
	language.open_manual()
end

local desc = {}

local function button_text_meta(button_list)
	local meta = {}
	function meta:__index(key)
		local obj = button_list[key] or {}
		obj.text = obj.text or "button.menu." .. key
		self[key] = obj
		return obj
	end
	return meta
end

local function wait_for_return(button_list)
	local button_text = setmetatable({}, button_text_meta(button_list))
	local function button_enable(buttons, enable)
		if enable then
			for k, what in pairs(buttons) do
				local name = what
				if type(what) == "table" then
					name = what[1]
				end
				vdesktop.button_enable(k, button_text[name])
			end
		else
			for k, what in pairs(buttons) do
				vdesktop.button_enable(k)	
			end
		end
	end
	local buttons = buttons_cache[button_list]
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
				local desc = button_text[button_key]
				desc.disable = not flag
				vdesktop.button_enable(menu_key, desc)
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
				local v = button_list[menu]
				vtips.set(v and v.tips or "tips.menu."..menu, v)
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
					local v = button_list[click]
					if v then
						r = action[v.action](button_list, v)
					else
						r = action[click]()
					end
					if level2_key then
						level2(buttons[level2_key])
					end
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
	local r = wait_for_return(button_list)
	vtips.pop()
	return r
end
