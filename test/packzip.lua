local settings = require "soluna".settings()
local lfs = require "soluna.lfs"
local zip = require "soluna.zip"

local filelist = {
	"asset",
	"core",
	"gameplay",
	"localization",
	"service",
	"visual",
	"main.game",
	"main.lua",
	"LICENSE",
}

local output = assert(settings.output, "Need output filename")
local ziplevel = settings.ziplevel

local function zip_add(f, pathname)
	local t = lfs.attributes(pathname, "mode")
	if t == "file" then
		print("Add file", pathname)
		f:addfile(pathname, pathname, ziplevel)
	elseif t == "directory" then
		print("Add dir", pathname)
		for n in lfs.dir(pathname) do
			if n:sub(1,1) ~= "." then
				zip_add(f, pathname .. "/" .. n)
			end
		end
	else
		error("Invalid filename " .. pathname)
	end
end

local f = assert(zip.open(output, "w"), "Can't create zipfile " .. output)

for _, name in ipairs(filelist) do
	zip_add(f, name)
end

f:close()



