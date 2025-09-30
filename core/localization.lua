local tointeger = math.tointeger

global pairs, type, ipairs, print, tostring, error, print_r

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

function localization.load(source)
	TEXT = {}
	for k,v in pairs(source) do
		TEXT[k] = v
	end
	for k,v in pairs(source) do
		TEXT[k] = substitution(v)
	end
end

function localization.convert(str, args)
	local t = TEXT[str]
	if t == nil then
		return str
	end
	local function subargs(tag)
		tag = tag:sub(2,-2)
		local realtag, def = tag:match "(.-)|(.*)"
		if realtag then
			tag = realtag
		end
		local tbl = args
		for k in tag:gmatch "[^.]+" do
			local key = tointeger(k) or k
			local subtbl = tbl[key]
			if not subtbl then
				if def then
					return def
				else
					return tag
				end
			else
				tbl = subtbl
			end
		end
		return tostring(tbl)
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
	local i = 0
	repeat
		t = replacement(t)
		i = i + 1
		if i > 100 then
			error ("Too depth replacement :" .. t)
		end
	until not t:find "${[^}]*}"
	return t
end

return localization
