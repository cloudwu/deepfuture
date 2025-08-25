local util = require "core.util"
local config = require "core.rules".ui

local sin = math.sin

global none

local color = {}

local size <const> = config.track.focus_duration

local function argb(c)
	return (c >> 24) & 0xff,
		(c >> 16) & 0xff,
		(c >> 8) & 0xff,
		c & 0xff
end

local function blend(a,b,factor)
	return (b * factor + a * (1-factor)) // 1
end

local color_cache = util.cache(function(c)
	local a = c >> 32
	local b = c & 0xffffffff
	local r = {}
	for i = 1, size do
		local f = i / size
		local a1,a2,a3,a4 = argb(a)
		local b1,b2,b3,b4 = argb(b)
		a1 = blend(a1, b1, f)
		a2 = blend(a2, b2, f)
		a3 = blend(a3, b3, f)
		a4 = blend(a4, b4, f)
		r[i] = a1 << 24 | a2 << 16 | a3 << 8 | a4
	end
	return r
end)

function color.blend(a,b)
	local key = a << 32 | b
	local c = color_cache[key]
	return function (factor)
		return c[factor]
	end
end

return color
