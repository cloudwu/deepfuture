local language = require "core.language"
local menu = require "gameplay.menu"
local table = table

global print_r, ipairs

local lang = {}

local function init_menu()
	local m = {}
	language.menu(m)
	local r = m[1]
	table.remove(r, 1)
	for i, key in ipairs(r) do
		r[key] = m[key]
	end
	r.language = {}
	return r
end

return function()
	local MENU = init_menu()
	print_r(MENU)
	menu(MENU)
	return "load"
end