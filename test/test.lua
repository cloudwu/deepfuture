--math.randomseed(0)
local version = require "gameplay.version"
local persist = require "gameplay.persist"
local init = require "gameplay.initial"
local setup = require "gameplay.setup"

print("Full:", version.full())
print("Major:", version.major())
print(version.newer_than("0.2.1", "0.2.0"))
print(version.older_than("0.1.1", "0.2.0"))

--[[
init.new()

print_r("HAND", setup.draw_worlds())
print_r(setup.new_world())
print_r("NEUTRAL", setup.neutral())

persist.save "test.dl"
]]

local localization = require "core.localization"

localization.load("localization/schinese.dl", "schinese")
print(localization.convert("abc", {
	name = "$(NAME.a)",
	value = {
		x = "XXX",
	}
}))
