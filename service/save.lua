local persist = require "gameplay.persist"
local util = require "core.util"
local advancement = require "gameplay.advancement"
local math = math
local string = string
local table = table
global error, assert, tostring, type, pairs, print_r, print, ipairs

local profile = {}

local save = {}

function save.new_profile(name, filename)
	assert(profile[name] == nil)
	profile[name] = {
		_filename = filename,
		deck = {},
	}
end

local function optional(init)
	for k,v in pairs(init) do
		if v:sub(-1) == "|" then
			init[k] = { type = v:sub(1, -2) , optional = true }
		else
			init[k] = { type = v }
		end
	end
	return init
end

local card_allow_keys = optional {
	type = "string",
	suit = "string",
	value = "number",
	name = "string|",
	sector = "number|",
	era = "number",
	adv1 = "table|",
	adv2 = "table|",
	adv3 = "table|"
}

local adv_allow_keys = optional {
	suit = "string",
	value = "number|",
	era = "number|",
	chosen = "boolean|",
}

local sector_allow_keys = optional {
	n = "number",
	camp = "string|",
}

local track_allow_keys = optional {
	C = "number",
	M = "number",
	X = "number",
	S = "number",
}

local pile_list = {
	"draw",
	"discard",
	"hand",
	"challenge",
	"colony",
	"homeworld",
	"neutral",
}

local function add_pile(t)
	for _, name in ipairs(pile_list) do
		t[name] = "table"
	end
	return t
end

local game_allow_keys = optional(add_pile {
	phase      = "string",
	seen       = "number",
	upkeep     = "table",
	seed       = "number",
	action1    = "string|",
	action2    = "string|",
})

local function checker(allow_keys)
	return function (what, obj)
		if obj == nil then
			return
		end
		for k, v in pairs(obj) do
			local allow_type = allow_keys[k]
			if not allow_type then
				error ("Invalid key " .. k .. " for card " .. what)
			end
			if type(v) ~= allow_type.type then
				error ("Invalid type " .. tostring(v) .. " (should be " .. allow_type.type .. " for card " .. what)
			end
		end
		for k,v in pairs(allow_keys) do
			if not v.optional and obj[k] == nil then
				error ("Missing ." .. k .. " for card " .. what)
			end
		end
		return obj
	end
end

local check_adv = checker(adv_allow_keys)
local check_card = checker(card_allow_keys)

local function name(card)
	local cname = card.name or ""
	if card.sector then
		return string.format("%s(%d)", cname, card.sector)
	else
		return cname
	end
end

local function adv(v)
	if v == nil then
		return ""
	end
	local str
	if v.value then
		str = v.suit .. "." .. advancement.name(v.suit, v.value) .. "." .. v.era
	else
		-- suit only
		str = v.suit
	end
	if v.chosen then
		str = str.. "(X)"
	end
	return str
end

local BLANK_FMT = "$ID : [$VALUE$SUIT <$TYPE>]"
local ADV_FMT = "$ID : [$VALUE$SUIT <$TYPE> $NAME.$ERA $ADVA / $ADVB / $ADVC]"

local card_format = {
	blank = "$ID : [$VALUE$SUIT]",
	world = ADV_FMT,
	tech = ADV_FMT,
}


local function format_card(card_id, card)
	local fmt = card_format[card.type] or BLANK_FMT
	return (fmt:gsub("$(%u+)", {
		ID = card_id,
		VALUE = card.value,
		SUIT = card.suit,
		TYPE = card.type,
		NAME = name(card),
		ERA = card.era,
		ADVA = adv(card.adv1),
		ADVB = adv(card.adv2),
		ADVC = adv(card.adv3),
	}))
end

function save.sync_card(name, card_id, card_data)
	local data = profile[name] or error ("new_profile first : " .. tostring(name))
	check_card(card_id, card_data)
	check_adv(card_id .. ".adv1", card_data.adv1)
	check_adv(card_id .. ".adv2", card_data.adv2)
	check_adv(card_id .. ".adv3", card_data.adv3)

	local action
	if data.deck[card_id] then
		action = "SYNC"
	else
		action = "ADD"
	end
	data.deck[card_id] = card_data
	print(action, format_card(card_id, card_data))
end

local check_sector = checker(sector_allow_keys)

local function check_map(map)
	for sec, obj in pairs(map) do
		local sec = math.tointeger(sec) or error ("Invalid sector : " .. tostring(sec))
		check_sector(sec, obj)
	end
	print_r ("MAP", map)
	return map
end

local check_track = checker(track_allow_keys)
local check_game = checker(game_allow_keys)

local function print_pile(what, t)
	if #t > 0 then
		print(what, table.concat(t, " "))
	end
end

local function check_pile(err, cards, data, name)
	local p = data.game[name]
	for _, id in ipairs(p) do
		if type(id) ~= "number" then
			err[#err+1] = "Invalid card in " .. name
		end
		if cards[id] ~= true then
			if cards[id] == nil then
				err[#err+1] = "No card " .. id .. " in " .. name
			else
				err[#err+1] = "card " .. id .. " from " .. name .. " already exist in " .. name
			end
		else
			cards[id] = name
		end
	end
end

-- for debug
-- todo : remove it if slow
local function card_verify(data)
	local all_cards = {}
	local err = {}
	for id in pairs(data.deck) do
		if type(id) == "number" then
			if all_cards[id] then
				err[#err+1] = "Card " .. id .. " is duplicate"
			end
			all_cards[id] = true
		end
	end
	check_pile(err, all_cards, data, "hand")
	check_pile(err, all_cards, data, "draw")
	check_pile(err, all_cards, data, "discard")
	check_pile(err, all_cards, data, "homeworld")
	check_pile(err, all_cards, data, "colony")
	check_pile(err, all_cards, data, "neutral")
	check_pile(err, all_cards, data, "challenge")
	
	for id, where in pairs(all_cards) do
		if where == true then
			err[#err+1] = "Card " .. tostring(id) .. " is missing"
		end
	end
	if #err > 0 then
		error(table.concat(err, "\n"))
	end
end

function save.sync_game(name, desktop)
	local data = profile[name] or error ("new_profile first : " .. tostring(name))
	data.galaxy = check_map(desktop.map)
	data.track = check_track("track", desktop.track)
	print_r("TRACK", data.track)
	desktop.game.phase = desktop.phase
	desktop.game.seed = desktop.seed
	print("PHASE", desktop.phase,  "SEEN", desktop.game.seen, "SEED", desktop.game.seed)
	data.game = check_game("game", desktop.game)
	print_r("UPKEEP", data.game.upkeep)
	for _, name in ipairs(pile_list) do
		print_pile(name, data.game[name])
	end
	
	card_verify(data)
end

function save.sync_history(name, history)
	local data = profile[name] or error ("new_profile first : " .. tostring(name))
	data.history = history
	print_r("HISTORY", history)	
end

function save.save_game(name)
	local data = profile[name] or error ("new_profile first : " .. tostring(name))
	local filename = data._filename
	persist.save(filename, data)
	print("SAVE", filename)
end

function save.load_game(name)
	local predata = profile[name] or error ("new_profile first : " .. tostring(name))
	local filename = predata._filename
	local ok, data = persist.load(filename)
	if not ok then
		print("LOADERR", filename, data)
		return false
	else
		data._filename = filename
		profile[name] = data
		print("LOAD", filename)
		return true, data
	end
end

function save.init_deck(name)
	local data = profile[name] or error ("new_profile first : " .. tostring(name))
	data.deck = {}
	print("INITDECK")
end

return save