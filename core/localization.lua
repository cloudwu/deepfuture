local datalist = require "soluna.datalist"
local file = require "soluna.file"

local localization = {}

local TEXT

local function substitution(text)
	local function subtext(bracket_tag)
		bracket_tag = bracket_tag:sub(2,-2)
		local convert = TEXT[bracket_tag]
		if convert then
			TEXT[bracket_tag] = nil
			local t = substitution(convert)
			TEXT[bracket_tag] = t
			return t
		else
			return bracket_tag
		end
	end
	return (text:gsub("$(%b())", subtext))
end

local function load_text(filename, lang)
	local data = datalist.parse(file.loader(filename))[lang]
	if data then
		for k,v in pairs(data) do
			TEXT[k] = v
		end
	end
	for k,v in pairs(TEXT) do
		TEXT[k] = nil
		TEXT[k] = substitution(v)
	end
end

function localization.load(filename, lang)
	TEXT = {}
	if type(filename) == "table" then
		for _, name in ipairs(filename) do
			load_text(name, lang)
		end
	else
		load_text(filename, lang)
	end
end

function localization.convert(str, args)
	local t = TEXT[str]
	if t == nil then
		return str
	end
	local function subargs(tag)
		tag = tag:sub(2,-2)
		local tbl = args
		for key in tag:gmatch "[^.]+" do
			tbl = tbl[key]
			if tbl == nil then
				return tag
			end
		end
		return tbl
	end
	local s = t:gsub("$(%b{})", subargs)
	local function subtext(tag)
		tag = tag:sub(2, -2)
		local t = TEXT[tag]
		if t then
			return t
		else
			return tag
		end
	end
	return (s:gsub("$(%b())", subtext))
end

return localization
