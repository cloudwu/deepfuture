local settings = require "soluna".settings()

global tostring, tonumber

local version = {}

local ver = tostring(settings.version)

function version.full()
	return ver
end

local function version_number(v)
	local a,b,c = v:match "(%d+)%.(%d+)%.(%d+)"
	return tonumber(a), tonumber(b), tonumber(c)
end

function version.major()
	local a,b = version_number(ver)
	return a .. "." .. b
end

function version.newer_than(v1, v2)
	local a1,b1,c1 = version_number(v1)
	local a2,b2,c2 = version_number(v2)
	if a1 == a2 then
		if b1 == b2 then
			return c1 > c2
		else
			return b1 > b2
		end
	else
		return a1 > a2
	end
end

function version.older_than(v1, v2)
	local a1,b1,c1 = version_number(v1)
	local a2,b2,c2 = version_number(v2)
	if a1 == a2 then
		if b1 == b2 then
			return c1 < c2
		else
			return b1 < b2
		end
	else
		return a1 < a2
	end
end

return version


