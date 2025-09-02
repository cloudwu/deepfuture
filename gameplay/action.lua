local card = require "gameplay.card"
local vcard = require "visual.card"
local flow = require "core.flow"
local focus = require "core.focus"
local vdesktop = require "visual.desktop"
local vtips = require "visual.tips".layer "hud"
local map = require "gameplay.map"
local show_desc = require "gameplay.desc"
local rules = require "core.rules".phase
local ui = require "core.rules".ui
local look = require "gameplay.look"
local vbutton = require "visual.button"
local util = require "core.util"
local persist = require "gameplay.persist"
local sync = require "gameplay.sync"
local effect = require "gameplay.effect"
require "gameplay.effect"

global pairs, print, ipairs, print_r, error, require

local BUTTONS = {
	button1 = {
		action = "plan",
		text = "button.action.plan",
	},
	button2 = {
		action = "actionskip",
		text = "button.action.skip",
		n = 2,
	},
}

local function button_enable(what, enable)
	if what == nil then
		for name,v in pairs(BUTTONS) do
			vdesktop.button_enable(name, enable and v)
		end
	else
		vdesktop.button_enable(what, enable and BUTTONS[what])
	end
end

local expain_region = {
	homeworld = true,
	hand = true,
	colony = true,
	neutral = true,
}

-- todo : other action
local ACTION = {
	power = require "gameplay.power",
	advance = require "gameplay.advance",
	grow = require "gameplay.grow",
	settle = require "gameplay.settle",
}

local SUITS <const> = util.keys(rules.action)

local function create_plan_card(newcard)
	local suit_card = {}
	for idx,suit in ipairs(SUITS) do
		local c = util.shallow_clone(newcard, {})
		c.suit = suit
		c._marker = card.suit_info(c)
		suit_card[c] = true
		flow.sleep(5)
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "float")
		vcard.mask(c, true)
	end
	
	local focus_state = {}
	local desc = {}
	local choose
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "float" then
				desc.suit = focus_state.object._marker
				vtips.set("tips.plan.choose_suit", desc)
			else
				vtips.set "tips.plan.invalid"
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c, where = focus.click "left"
		if c and where == "float" then
			choose = c
			vtips.set()
			break
		end
		flow.sleep(0)
	end
	for c in pairs(suit_card) do
		vcard.mask(c)
		if c ~= choose then
			vdesktop.transfer("float", c, "deck")
			flow.sleep(5)
		end
	end
	local value_card = card.draw_discard() or error "No cards in draw pile"
	vcard.mask(value_card, true)
	vdesktop.add("deck", value_card)
	vdesktop.transfer("deck", value_card, "float")
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "float" and focus_state.object == value_card then
				desc.value = value_card.value
				vtips.set("tips.plan.choose_value", desc)
			else
				vtips.set()
			end
		elseif focus_state.lost then
			vtips.set()
		end
		if focus.click "left" == value_card then
			vcard.mask(value_card)
			newcard.suit = choose.suit
			newcard.value = value_card.value
			newcard._marker = value_card.value .. choose._marker
			vcard.flush(newcard)
			vdesktop.replace("float", choose, newcard)
			vdesktop.transfer("float", value_card, "deck")
			flow.sleep(30)
			break
		end
		flow.sleep(0)
	end
	vtips.set()
	-- discard hands
	while true do
		local c = card.card("hand", 1)
		if c == nil then
			break
		end
		c = card.pickup("hand", c)
		card.discard(c)
		vdesktop.transfer("hand", c, "deck")
		flow.sleep(5)
	end
	card.putdown("hand", newcard)
	vdesktop.transfer("float", newcard, "hand")
end

-- society can settle on a new world
local function has_society(pile)
	local n = 1
	while true do
		local c = card.card(pile, n)
		if not c then
			return
		end
		if card.has_advancement(c, pile, "society") then
			return c
		end
		n = n + 1
	end
end

local function merge_last(hands, last)
	if last then
		for c, enable in pairs(last) do
			if hands[c] == nil and enable then
				vcard.mask(c)
			end
		end
	end
	for c, enable in pairs(hands) do
		vcard.mask(c, enable)
	end
	return hands
end

local function check_settle(hands, play_card)
	if play_card.suit ~= "M" then
		return true
	end
	local can_settle = true
	for c in pairs(hands) do
		if c ~= play_card then
			if c.type == "world" then
				if map.player_ctrl(c.sector) then
					return true
				else
					can_settle = false
				end
			elseif card.has_advancement(c, "hand", "society") then
				return true
			end
		end
	end
	return can_settle
end

local function ctrl_neutral()
	local n = 1
	while true do
		local c = card.card("neutral", n)
		if not c then
			return false
		end
		if map.player_ctrl(c.sector) then
			return true
		end
		n = n + 1
	end
end

local function check_action(last)
	local can_grow = map.can_grow()
	local hands = {}
	local n = 1
	while true do
		local c = card.card("hand",n)
		if not c then
			break
		end
		n = n + 1
		if not can_grow and c.suit == "R" then
			hands[c] = false
		else
			hands[c] = true
		end
	end
	if ctrl_neutral() or has_society "homeworld" or has_society "colony" then
		return merge_last(hands, last)
	end
	
	for c in pairs(hands) do
		hands[c] = check_settle(hands, c)
	end

	return merge_last(hands, last)
end

local function clear_mask(hands)
	for c, enable in pairs(hands) do
		if enable then
			vcard.mask(c)
		end
	end
end

local function choose_action(hands)
	local desc = {
		action = nil,
		desc = nil,
		seen = nil
	}
	
	local last_action
	local function nomore_action()
		local n = BUTTONS.button2.n - 1
		if n <= 0 then
			return true
		end
		BUTTONS.button2.n = n
		
		for c, enable in pairs(hands) do
			if enable then
				local action = rules.action[c.suit]
				if action == last_action then
					hands[c] = false
					vcard.mask(c)
				end
			end
		end
		return false
	end

	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			local where = focus_state.active
			local c = focus_state.object
			if where == "hand" then
				desc.action = "$(action." .. rules.action[c.suit] .. ")"
				if hands[c] then
					if c.suit == "H" and map.is_safe() then
						desc.desc = "$(action." .. rules.action[c.suit] .. ".desc.safe)"
					else
						desc.desc = "$(action." .. rules.action[c.suit] .. ".desc)"
					end
					vtips.set("tips.action.choose", desc)
				else
					local action_name = rules.action[c.suit]
					if action_name == last_action then
						vtips.set("tips.action.unique", desc)
					else
						desc.desc = "$(action." .. rules.action[c.suit] .. ".desc.invalid)"
						vtips.set("tips.action.invalid", desc)
					end
				end
			elseif where == "discard" then
				desc.seen = card.seen()
				if desc.seen > 0 then
					vtips.set("tips.look.pile", desc)
				end
			elseif BUTTONS[where] then
				vtips.set("tips.button." .. BUTTONS[where].action,BUTTONS[where])
			elseif focus_state.object then
				vtips.set("tips.action." .. where)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c, where = focus.click "right"
		if c and expain_region[where] then
			vtips.set()
			show_desc.action {
				region = where,
				card = c,
			}
		end
		local c, where = focus.click "left"
		if where == "discard" then
			local n = card.seen()
			if n > 0 then
				look.start(n)
			end
		elseif BUTTONS[where] then
			if BUTTONS[where].action == "plan" then
				vtips.set()
				return card.plan_blankcard(), hands
			else
				-- action skip
				break
			end
		elseif hands[c] then
			-- execute action
			local action_name = rules.action[c.suit]
			local f = ACTION[action_name]
			if f then	-- todo: remove it when finish all actions
				vtips.set()
				clear_mask(hands)
				c = card.pickup("hand", c)
				card.discard(c)
				vdesktop.transfer("hand", c, "deck")
				button_enable(nil)
				f()
				button_enable(nil, true)
				hands = check_action(hands)
				vtips.set()
				vdesktop.set_text("phase", { extra = false } )
				last_action = action_name
				if nomore_action() then
					break
				end
				button_enable("button2", true)
			end
		end
		flow.sleep(0)
	end
	-- no plan (nil)
	return nil, hands
end

return function ()
	sync()
	local plan_card
	local hands = check_action()
	button_enable(nil, true)

	vdesktop.set_text("phase", { text = "$(phase.action)" } )
	plan_card, hands = choose_action(hands)
	button_enable()
	clear_mask(hands)
	
	if plan_card then
		create_plan_card(plan_card)
	end
	
	return "payment"
end
