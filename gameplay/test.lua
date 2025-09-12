local datalist = require "soluna.datalist"
local file = require "soluna.file"
local card = require "gameplay.card"
local soluna = require "soluna"
local map = require "gameplay.map"
local track = require "gameplay.track"
local table = table

global ipairs, print, tostring, print_r

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
		return true
	end
end

local patch = {}

local function add_hand(action)
	if action.type == "track" then
		if action.n > 0 then
			track.advance(action.what, action.n)
		else
			track.use(action.what, -action.n)
		end
	elseif action.type == "drop" then
		card.drophand()
	elseif action.type == "galaxy" then
		if action.n then
			local camp = action.camp or "player"
			map.set_galaxy(action.sector, action.n, camp)
			if camp == "player" then
				map.settle(action.sector)
			end
		end
		if action.wonder then
			map.set_sector_name(action.sector, action.name or "TEST")
			map.set_sector_wonder(action.sector, action.wonder, action.suit or "S")
		end
	else
		-- add new card
		local c = card.test_newcard(action)
		if action.to == "seen" then
			print("Put on draw pile", c)
			card.puttop(c)
		else
			card.putdown(action.to or "hand", c)
		end
	end
end

function patch.setup(data)
	for _, action in ipairs(data) do
		add_hand(action)
	end
end

function patch.start(data)
	for _, action in ipairs(data) do
		add_hand(action)
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

local function dump(what)
	if card.count(what) == 0 then
		return
	end
	local tmp = { what }
	local n = 1
	while true do
		local c = card.card(what, n)
		if c then
			tmp[#tmp+1] = tostring(c)
			n = n + 1
		else
			break
		end
	end
	print(table.concat(tmp, " "))
end

function test.dump()
	dump "hand"
	dump "homeworld"
	dump "colony"
end

return test
