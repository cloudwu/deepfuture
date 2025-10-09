local datalist = require "soluna.datalist"
local file = require "soluna.file"
local lfs = require "soluna.lfs"
local soluna = require "soluna"
local io = io

global tostring, pairs, print

local setting = {}

local SETTING

function setting.path()
	local dir = soluna.gamedir "deepfuture"
	return dir
end

function setting.load()
	local filename = setting.path().."setting.dl"
	if file.exist(filename) then
		SETTING = datalist.parse(file.load(filename))
	else
		SETTING = {}
	end
	return SETTING
end

function setting.get()
	return SETTING
end

function setting.save()
	local filename = setting.path().."setting.dl"
	SETTING = SETTING or {}
	local f <close> = io.open(filename, "wb")
	print("Setting update")
	for k,v in pairs(SETTING) do
		print("Setting:",k,v)
		f:write(k, " : " , tostring(v) , "\n")
	end
	f:close()
end

return setting
