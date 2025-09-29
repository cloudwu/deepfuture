local language = require "core.language"
local menu = require "gameplay.menu"
local setting = require "core.setting"
local loadsave = require "core.loadsave"
local flow = require "core.flow"

global print, print_r

local savefile = {
	"save.txt",
	"save2.txt",
	"save3.txt",
}

local function choose_profile(m)
	local dir = setting.path()
	local item = { "start" }
	for i = 1, 3 do
		local key = "profile_" .. i
		item[i+1] = key
		local filename = dir .. savefile[i]
		local data = {
			text = "button.menu.newgame",
			tips = "tips.menu.newgame",
			font_size = 14,
			action = "profile_select",
			profile = "PROFILE_" .. i,
			savefile = filename,
		}
		local ok, info = loadsave.profile_info(filename)
		if ok then
			data.text = "button.menu.continue"
			data.tips = "tips.menu.continue"
			data.turn = info.history.year
			data.time = language.time(info.file_attributes.modification)
		end
		m[key] = data
	end
	m[#m+1] = item
end

return function()
	local MENU = {}

	choose_profile(MENU)
	language.menu(MENU)

	MENU[#MENU+1] = "exit"
	return menu(MENU) or flow.state.startmenu
end