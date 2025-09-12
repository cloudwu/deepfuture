local flow = require "core.flow"
local mouse = require "core.mouse"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips" .layer "desc"
local card = require "gameplay.card"
local advancement = require "gameplay.advancement"
local ui = require "core.rules".ui
local phase = require "core.rules".phase
local vic_rules = require "core.rules".victory
local table = table

global print_r, print

local function gen_adv_(c, stage, desc)
	local stage = "adv"..stage
	local s = c[stage]
	if s and s.value then
		desc[stage] = "$(desc." .. stage .. ")"
		desc[stage.."_discard"] = "$(desc." .. stage .. ".discard)"
		local prefix = "$(adv.".. advancement.name(s.suit, s.value).. "."
		desc[stage.."_name"] = prefix .. "name)"
		desc[stage.."_era"] = s.era
		desc[stage.."_stage"] = "$(" .. advancement.stage(s.suit, s.value) .. ")"
		desc[stage.."_desc"] = prefix .. "detail)"
	else
		desc[stage] = nil
		desc[stage.."_discard"] = nil
	end
end

local function gen_adv(c, desc)
	for i = 1, 3 do
		gen_adv_(c, i, desc)
	end
	if c.type ~= "tech" or not card.complete(c) then
		return
	end
end

local M = {}

local function show_card(args)
	local c = args.card
	vdesktop.clear "card"
	vdesktop.add("card", c)
	return c
end

local function wait_for_return(desc)
	vdesktop.describe(desc)
	-- todo
	vtips.push()
	vtips.set "tips.desc.return"
	flow.sleep(0)	-- flush focus
	local focus_state = {}
	while true do
		mouse.get(focus_state)
		if mouse.click(focus_state, "right") or mouse.click(focus_state, "left") then
			break
		end
		flow.sleep(0)
	end
	vdesktop.describe(false)
	vtips.pop()
end

local function gen_desc(c, desc)
	if c.type == "civ" then
		desc.world = c.world
		desc.victory = c._victory
		desc.advancement = c._advancement
	end
end

function M.action(args)
	local c = show_card(args)
	local card_type = c.type
	if (card_type == "tech" or card_type == "world") and card.complete(c) then
		card_type = card_type .. ".complete"
	end
	local desc = {
		content = "$(desc.text.info)",
		detail = "$(desc.text." .. args.region .. "." .. card_type .. ")",
		type = "$(card.type." .. c.type .. ")",
		place = "$(desc.place.".. args.region .. ")",
		sector = c.sector,
		name = c.name,
		era = c.era,
		payment = card.payment_text(c),
		vic_tech = vic_rules.condition.tech,
		vic_colony = vic_rules.condition.colony,
	}
	if c.suit then
		desc.suit = card.suit_info(c)
		desc.action = "$(action." .. phase.action[c.suit] .. ")"
		desc.action_desc = "$(action." .. phase.action[c.suit] .. ".detail)"
	end
	gen_adv(c, desc)
	gen_desc(c, desc)
	wait_for_return(desc)
end

function M.start(args)
	local c = show_card(args)
	local prefix = "$(adv.".. args.name .. "."
	local desc = {
		type = "$(card.type." .. c.type .. ")",
		place = "$(desc.place.".. args.region .. ")",
		detail = "$(desc.start." .. args.region .. "." .. c.type .. ")",
		adv_name = prefix .. "name)",
		adv_desc = prefix .. "detail)",
	}
	gen_desc(c, desc)
	wait_for_return(desc)
end

return M