local datalist = require "soluna.datalist"
local file = require "soluna.file"
local lfs = require "soluna.lfs"
local util = require "core.util"
local localization = require "core.localization"
local soluna = require "soluna"
local font = require "soluna.font"
local sysfont = require "soluna.font.system"
local vdesktop = require "visual.desktop"
local setting = require "core.setting"
local url = require "soluna.url"

global print, assert, print_r, error, pairs, os

local LOCALIZATION_PATH = "localization/"
local DOT <const> = 46	; assert(("."):byte() == DOT)

local lang = {}
local DATA
local LANG = "schinese"

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

function lang.switch(name)
	if DATA[name] == nil then
		name = lang.get_default()
	end
	LANG = name
	localization.load(DATA[name])
end

function lang.switch_flush(name)
	lang.switch(name)
	local font_id = lang.font_id(name)
	vdesktop.change_font(font_id)
	soluna.set_window_title(localization.convert "app.title")
	vdesktop.change_font(font_id)
	local s = setting.get()
	s.language = LANG
	setting.save()
end

-- todo : read user settings
function lang.get_default()
	local settings = soluna.settings()
	local lang = settings.lang or "english"
	
	if not DATA[lang] then
		print("Language " .. lang .. " not found, falling back to schinese")
		lang = "english"
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

function lang.menu(m)
	local r = { "language" }
	local i = 1
	for k,v in pairs(DATA.setting) do
		local key = "lang_" .. i
		m[key] = {
			lang = k,
			name = v.name,
			english_name = v.english_name or v.name,
			text = "button.menu.lang_select",
			tips = "tips.menu.lang_select",
			action = "lang_select",
			font_id = lang.font_id(k),
		}
		i = i + 1
		r[i] = key
	end
	m.language = {
		name = DATA.setting[LANG].name
	}
	m[#m+1] = r
end

function lang.time(t)
	local lang_setting = DATA.setting[LANG] or error ("No lang setting : " .. LANG)
	local fmt = lang_setting.timefmt or error ("No timefmt : " .. LANG)
	return os.date(fmt, t)
end

function lang.open_manual()
	local lang_setting = DATA.setting[LANG] or error ("No lang setting : " .. LANG)
	url.open(lang_setting.homepage)
end

return lang