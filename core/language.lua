local datalist = require "soluna.datalist"
local file = require "soluna.file"
local lfs = require "soluna.lfs"
local util = require "core.util"
local localization = require "core.localization"
local soluna = require "soluna"
local font = require "soluna.font"
local sysfont = require "soluna.font.system"

global print, assert, print_r, error

local LOCALIZATION_PATH = "localization/"
local DOT <const> = 46	; assert(("."):byte() == DOT)

local lang = {}
local DATA

function lang.init()
	local data = {}
	for filename in lfs.dir(LOCALIZATION_PATH) do
		if filename:byte() ~= DOT then
			local t = datalist.parse (file.loader(LOCALIZATION_PATH .. filename))
			util.merge_table(data, t)
		end
	end
	DATA = data
end

-- todo : flush visual
function lang.switch(lang)
	if DATA[lang] == nil then
		lang = "schinese"	-- default language
	end
	localization.load(DATA[lang])
end

-- todo : read user settings
function lang.get_default()
	local settings = soluna.settings()
	local lang = settings.lang or "schinese"
	
	if not DATA[lang] then
		print("Language " .. lang .. " not found, falling back to schinese")
		lang = "schinese"
	end
	
	print("Using language: " .. lang)
	return lang
end

function lang.font_id(lang)
	local lang_setting = DATA.setting[lang] or error ("No lang setting : " .. lang)
	local gamefont = lang_setting.font or lang_setting[soluna.platform].font
	if not lang_setting.font_import then
		font.import(assert(sysfont.ttfdata (gamefont)))
		lang_setting.font_import = true
	end
	return font.name(gamefont)
end

return lang