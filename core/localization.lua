local datalist = require "soluna.datalist"
local file = require "soluna.file"
local tointeger = math.tointeger
global pairs, type, ipairs, print

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
		for k in tag:gmatch "[^.]+" do
			local key = tointeger(k) or k
			local subtbl = tbl[key]
			if subtbl == nil then
				local key, def = key:match "(.-)|(.*)"
				if key then
					key = tointeger(key) or key
					local v = tbl[key]
					if v and type(v) ~= "table" then
						return v
					else
						return def
					end
				end
				return tag
			else
				tbl = subtbl
			end
		end
		return tbl
	end
	local function replacement(text)
		-- todo : support default value ${key|default}
		local s = text:gsub("$(%b{})", subargs)
		local function subtext(tag)
			tag = tag:sub(2, -2)
			local text = TEXT[tag]
			if text then
				return text
			else
				return tag
			end
		end
		return (s:gsub("$(%b())", subtext))
	end
	repeat
		t = replacement(t)
	until not t:find "${"
	return t
end

return localization
