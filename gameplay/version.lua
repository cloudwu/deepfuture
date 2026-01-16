local settings = require "soluna".settings()
local file = require "soluna.file"
local crypt = require "soluna.crypt"

global tostring, tonumber, table, assert, print, string

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

local root_list = {
	"asset",
	"core",
	"gameplay",
	"localization",
	"service",
	"visual",
	"main.lua",
	"main.game",
}

local DOT <const> = 46; assert(DOT == ("."):byte())

local function sha1(text)
	local binary = crypt.sha1(text)
	return crypt.hexencode(binary)
end

local function calc_hash(path, filelist)
	local n = #filelist
	for i = 1, n do
		local fullpath = path .. filelist[i]
		local t = file.attributes(fullpath, "mode")
		if t == "file" then
			local content = file.load(fullpath)
			n = n + 1
			filelist[n] = sha1(content)
		elseif t == "directory" then
			local sublist = {}
			local j = 1
			for name in file.dir(fullpath) do
				if name:byte() ~= DOT then
					sublist[j] = name
					j = j + 1
				end
			end
			table.sort(sublist)
			n = n + 1
			filelist[n] = calc_hash(fullpath .. "/", sublist)
		end
	end
	return sha1(table.concat(filelist))
end

local VERSION
function version.text()
	if VERSION == nil then
		local hash = calc_hash("", root_list)
		VERSION = string.format("%s.%s", ver, hash:sub(1, 5))
	end
	return VERSION
end

return version


