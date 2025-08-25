local datalist = require "soluna.datalist"
local file = require "soluna.file"
local card = require "gameplay.card"
local soluna = require "soluna"

global ipairs

local test = {}
local TESTCASE

function test.load(name)
	local filename = "asset/test/"..name..".dl"
	TESTCASE = datalist.parse (file.loader(filename))
end

function test.init()
	local settings = soluna.settings()
	if settings.test then
		test.load(settings.test)
	end
end

local patch = {}

function patch.setup(data)
	for _, action in ipairs(data) do
		if action.type == "drop" then
			card.drophand()
		else
			-- add new card
			local c = card.test_newcard(action)
			card.putdown("hand", c)
		end
	end
end

function test.patch(phase)
	if TESTCASE == nil then
		return
	end
	local data = TESTCASE[phase]
	if data == nil then
		return
	end
	patch[phase](data)
end

return test
