local card = require "gameplay.card"
local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips".layer "hud"
local map = require "gameplay.map"
local show_desc = require "gameplay.desc"
local rules = require "core.rules".phase

local function sleep()
	flow.sleep(5)
end

local function draw_hands()
	local hands = vdesktop.hands()
	local draw = rules.start.draw - #hands
	if draw > 0 then
		-- draw to 5 cards
		for i = 1, draw do
			local c = card.draw_hand()
			vdesktop.add("deck", c)
			vdesktop.transfer("deck", c, "hand")
			sleep()
		end
	end
	local discard = #hands - rules.start.hand_limit
	if discard > 0 then
		-- discard random card
		local discard_cards = {}
		for i = 1, discard do
			local n = math.random(#hands)
			local c = table.remove(hands, n)
			discard_cards[i] = c
			card.pickup("hand", c)
			card.discard(c)
			vdesktop.transfer("hand", c, "float")
			sleep()
		end
		flow.sleep(60)
		for i = 1, discard do
			vdesktop.transfer("float", discard_cards[i], "deck")
			sleep()
		end
	end
end

local function choose_action()
	local desc = {
		action = nil,
		desc = nil,
	}

	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			local where = focus_state.active
			local c = focus_state.object
			if where == "hand" then
				desc.action = "$(action." .. c.suit .. ")"
				if c.suit == "H" and map.is_safe() then
					desc.desc = "$(action." .. c.suit .. ".desc.safe)"
				else
					desc.desc = "$(action." .. c.suit .. ".desc)"
				end
				vtips.set("tips.action.choose", desc)
			elseif where ~= "discard" and focus_state.object then
				vtips.set("tips." .. where)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c, where = focus.click "right"
		if c and where ~= "discard" then
			vtips.set()
			show_desc {
				region = where,
				card = c,
			}
		end
		flow.sleep(0)
	end
end

local check = { disable = {} }

-- check settle
function check:M()
	
end

local function check_action()
end

return function ()
	vdesktop.set_text("phase", "$(phase.start)")
	draw_hands()

	vdesktop.set_text("phase", "$(phase.action)")
	choose_action()
	return "idle"
end
