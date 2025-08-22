local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips" .layer "desc"

local function suit_text(s)
	if s == nil then
		return ""
	else
		return "$(suit."..s.suit..")"
	end
end

local function gen_payment(c)
	return suit_text(c.adv1) ..
		suit_text(c.adv2) ..
		suit_text(c.adv3)
end

local function gen_adv_(c, stage, desc)
	local stage = "adv"..stage
	local s = c[stage]
	if s then
		desc[stage] = "$(desc." .. stage .. ")"
		local prefix = "$(adv.".. s.suit .. "." .. s.value .. "."
		desc[stage.."_name"] = prefix .. "name)"
		desc[stage.."_era"] = s.era
		desc[stage.."_stage"] = prefix .. "stage)"
		desc[stage.."_desc"] = prefix .. "detail)"
	else
		desc[stage] = ""
	end
end

local function gen_adv(c, desc)
	for i = 1, 3 do
		gen_adv_(c, i, desc)
	end
end

return function (args)
	local c = args.card
	vdesktop.clear "card"
	vdesktop.add("card", c)
	local desc = {
		detail = "$(desc.text." .. args.region .. "." .. c.type.. ")",
		type = "$(card.type." .. c.type .. ")",
		place = "$(desc.place.".. args.region .. ")",
		sector = c.sector,
		name = c.name,
		era = c.era,
		payment = gen_payment(c),
	}
	if c.suit then
		desc.suit = "$(suit." .. c.suit .. ")"
		desc.action = "$(action." .. c.suit .. ")"
		desc.action_desc = "$(action." .. c.suit .. ".detail)"
	end
	gen_adv(c, desc)
	vdesktop.describe(desc)
	-- todo
	vtips.push()
	vtips.set "tips.desc.return"
	while true do
		if focus.click "right" or focus.click "left" then
			break
		end
		flow.sleep(0)
	end
	vdesktop.describe(false)
	vtips.pop()
end
