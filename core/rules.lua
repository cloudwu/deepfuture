local util = require "core.util"
local datalist = require "soluna.datalist"
local file = require "soluna.file"

global none

local rules = util.cache(function (name)
	local filename = "asset/gameplay/"..name..".dl"
	local t = datalist.parse (file.loader(filename))
	return t
end)

return rules
