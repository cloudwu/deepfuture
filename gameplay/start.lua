local persist = require "gameplay.persist"
local card = require "gameplay.card"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local focus = require "core.focus"
local vtips = require "visual.tips".layer "hud"
local vbutton = require "visual.button"
local track = require "gameplay.track"
local advancement = require "gameplay.advancement"
--local map = require "gameplay.map"
local show_desc = require "gameplay.desc"
local rules = require "core.rules".phase
local class = require "core.class"
require "gameplay.effect"
local test = require "gameplay.test"

global print, ipairs, pairs, print_r, error, tostring

local function draw_hands()
	local draw = rules.start.draw - card.count "hand"
	if draw > 0 then
		-- draw to rules.start.draw(5) cards
		for i = 1, draw do
			local c = card.draw_hand()
			if c == nil then
				break
			end
			vdesktop.add("deck", c)
			vdesktop.transfer("deck", c, "hand")
			flow.sleep(5)
		end
	end
end

local function discard_hand_limit()
	local discard = card.count "hand" - rules.start.hand_limit
	if discard > 0 then
		vdesktop.set_text("phase", "$(phase.discard)")
		-- discard random card
		local focus_state = {}
		local desc = { limit = rules.start.hand_limit }
		local function wait_click(discard_card)
			while true do
				if focus.get(focus_state) then
					if focus_state.object == discard_card then
						vtips.set("tips.discard.focus", desc)
					else
						vtips.set("tips.discard.invalid", desc)
					end
				elseif focus_state.lost then
					vtips.set()
				end
				if focus.click "left" == discard_card then
					vcard.mask(discard_card)
					vtips.set()
					return
				end
				flow.sleep(0)
			end
		end
		
		for i = 1, discard do
			local c = card.discard_random_hand()
			vdesktop.transfer("hand", c, "float")
			vcard.mask(c, true)
			flow.sleep(0)
			wait_click(c)
			vdesktop.transfer("float", c, "deck")
		end
	end
end

local start_adv = {}

function start_adv.art()
	track.advance("C", 1)
end

local function discard_one_card(advs)
	vdesktop.set_text("phase", "$(phase.discard)")
	local discards = {}
	local n = 1
	while true do
		local c = card.card("hand", n)
		if c == nil then
			break
		end
		if not advs:is_used(c) then
			discards[#discards+1] = c
		end
		n = n + 1
	end
	advs:reset()
	for _, c in ipairs(discards) do
		vcard.mask(c, true)
	end
	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "hand" then
				if advs:is_used(focus_state.object) then
					vtips.set "tips.discard.computation.invalid"
				else
					vtips.set "tips.discard.computation"
				end
			else
				vtips.set()
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c = focus.click "left"
		if c and not advs:is_used(c) then
			local discard_card = card.pickup("hand", c)
			if discard_card then
				card.discard(discard_card)
				vdesktop.set_text("phase", "$(phase.start)")
				for _, c in ipairs(discards) do
					vcard.mask(c)
				end
				return discard_card
			end
		end
		flow.sleep(0)
	end
end

function start_adv.computation(advs)
	local c = card.draw_hand() or error "No more card"
	advs:add(c, "hand")
	vdesktop.add("deck", c)
	vdesktop.transfer("deck", c, "hand")
	flow.sleep(0)	-- release focus
	advs:update()
	local discard = discard_one_card(advs)
	vdesktop.transfer("hand", discard, "deck")
end

local function choose_cards(advs, n)
	local button = {
		text = "button.start",
		n = n,
	}
	local card_tips = {}
	local focus_state = {}
	
	vdesktop.button_enable("button1", button)
	
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "button1" then
				vtips.set("tips.start.skip", button)
			else
				local focus = advs:focus(focus_state.object)
				if focus then
					advancement.focus(focus)
					card_tips.adv = advancement.info(focus, "name")
					card_tips.effect = advancement.info(focus, "desc")
					local next_adv = advs:nextadv(focus_state.object)
					if next_adv then
						card_tips.nextadv = advancement.info(next_adv, "name")
						vtips.set("tips.start.card.multiple", card_tips)
					else
						vtips.set("tips.start.card.unique", card_tips)
					end
				else
					vtips.set()
				end
			end
		elseif focus_state.lost then
			vtips.set()
			track.focus(false)	-- disable all focus track
		end
		local switch_card, region = focus.click "right"
		if switch_card then
			if advs:can_use(switch_card) then
				local focus = advs:nextadv(switch_card, true)
				if not focus then
					-- unique adv, explain this card
					vtips.set()
					track.focus(false)
					show_desc.start {
						region = region,
						card = switch_card,
						name = advs:focus(switch_card),
					}
				else
					advancement.focus(focus)
					card_tips.adv = advancement.info(focus, "name")
					card_tips.effect = advancement.info(focus, "desc")
					local next_adv = advs:nextadv(focus_state.object)
					card_tips.nextadv = advancement.info(next_adv, "name")
					vtips.set("tips.start.card.multiple", card_tips)
				end
			end
		end
		local c, btn = focus.click "left"
		if c then
			if btn == "button1" then
				break
			end
			if advs:can_use(c) then
				track.focus(false)
				vtips.set(nil)
				local adv_name = advs:focus(c)
				advs:use(c)
				local f = start_adv[adv_name]
				if f then	-- todo : 
					vdesktop.button_enable("button1", nil)
					f(advs)
					vdesktop.button_enable("button1", button)
				end
				local n = advs:update()
				if n == 0 then
					-- no more advs available
					break
				end
				track.focus(false)
				vtips.set(nil)
				if n ~= button.n then
					button.n = n
					vbutton.update "button1"
				end
			else
				vtips.set(nil)
			end
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	vtips.set(nil)
end

local function sync(where)
	local p = test.get_pile(where)
	local diff = vdesktop.sync(where, p)
	if not diff then
		return
	end
	for _, c in ipairs(diff.discard) do
		print("START TEST DISCARD FROM", where, c)
		vdesktop.transfer(where, c, "deck")
		flow.sleep(5)
	end
	for _, c in ipairs(diff.draw) do
		print("START TEST DRAW TO", where, c)
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, where)
		flow.sleep(5)
	end
end

local function test_patch()
	test.patch "start"
	sync "hand"
	sync "homeworld"
	sync "colony"
end

local function discard_used_cards(advs)
	local cards = advs:used_cards()
	for _, c in ipairs(cards) do
		if card.pickup("hand", c) then
			card.discard(c)
			vdesktop.transfer("hand", c, "deck")
			flow.sleep(5)
		elseif card.pickup("colony", c) then
			card.discard(c)
			vdesktop.transfer("colony", c, "deck")
			flow.sleep(5)
		end
	end
end

return function ()
	test_patch()
	vdesktop.set_text("phase", "$(phase.start)")
	draw_hands()
	
	local advs = class.effect "START"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"
	
	local n = advs:update()
	if n > 0 then
		choose_cards(advs, n)
		discard_used_cards(advs)
		advs:reset()
	end
	discard_hand_limit()

	return "action"
end
