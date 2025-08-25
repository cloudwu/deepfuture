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
local test = require "gameplay.test"

global print, ipairs, pairs, print_r, error, tostring

local function draw_hands()
	local draw = rules.start.draw - card.count "hand"
	if draw > 0 then
		-- draw to 5 cards
		for i = 1, draw do
			local c = card.draw_hand()
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

local function set_card(advs, set)
	if set then
		local card_enable = {}
		for _, adv in ipairs(advs) do
			if adv.enable then
				card_enable[adv.card] = true
				vcard.mask(adv.card, true)
				if adv.index == set[adv.card].focus then
					vcard.focus_adv(adv.card, adv.index, true)
				end
			else
				if not card_enable[adv.card] then
					vcard.mask(adv.card)
				end
				local use
				if adv.use then
					use = false
				end
				vcard.focus_adv(adv.card, adv.index, use)
			end
		end
	else
		for _, adv in ipairs(advs) do
			vcard.mask(adv.card)
			vcard.focus_adv(adv.card, adv.index)
		end
	end
end

local function check_adv(advs)
	local n = 0
	for _, adv in ipairs(advs) do
		if not adv.use then
			local enable = card.check_adv(adv.name)
			adv.enable = enable
			if enable then
				n = n + 1
			end
		else
			adv.enable = nil
		end
	end
	return n
end

local function set_adv_focus(advs, last)
	local r = {}
	for _, adv in ipairs(advs) do
		if adv.enable then
			local f = r[adv.card]
			if not f then
				r[adv.card] = { focus = adv.index, adv.index }
			else
				f[#f+1] = adv.index
			end
		end
	end
	if last then
		for card, f in pairs(r) do
			if last[card] then
				local last_focus = last[card].focus
				if last_focus ~= f.focus then
					for _, index in ipairs(f) do
						if last_focus == index then
							f.focus = index
							break
						end
					end
				end
			end
		end
	end
	return r
end

local function find_next(obj, v)
	local n = #obj
	for i = 1, n do
		if obj[i] == v then
			return obj[i+1] or obj[1]
		end
	end
end

local function find_next_adv(c, obj)
	local current = obj.focus
	local current_name = vcard.adv_info(c, current)
	local n = #obj - 1
	for i = 1, n do
		local next = find_next(obj, current)
		local next_name = vcard.adv_info(c, next)
		if current_name  ~= next_name then
			return next
		end
		current = next
		current_name = next_name
	end
end

local start_adv = {}

function start_adv.art()
	advancement.process "art"
end

local function reset_cards_adv(advs)
	local n = check_adv(advs)
	if n == 0 then
		return
	end
	local focus_adv = set_adv_focus(advs)
	set_card(advs, focus_adv)
	return n, focus_adv
end

local function choose_cards(advs)
	local n, focus_adv = reset_cards_adv(advs)
	if not n then
		return
	end
	local function use_adv(c, index)
		for _, adv in ipairs(advs) do
			if adv.card == c and adv.index == index then
				adv.use = true
				return
			end
		end
		error ("Invalid use " .. tostring(c) .. " " .. index)
	end
	
	local button = {
		text = "button.start",
		n = n,
	}
	local card_tips = {}
	local focus_state = {}
	
	local function set_card_tips(c, obj)
		local adv_index = obj.focus
		card_tips.adv, card_tips.effect = vcard.adv_info(c, adv_index)
		local next_adv = find_next_adv(c, obj)
		if next_adv then
			card_tips.nextadv = vcard.adv_info(c, next_adv)
			vtips.set("tips.start.card.multiple", card_tips)
		else
			vtips.set("tips.start.card.unique", card_tips)
		end
	end
	
	local function change_next_focus_adv(switch_card)
		local f = focus_adv[switch_card]
		local next_adv = find_next_adv(switch_card, f)
		if next_adv then
			vcard.focus_adv(switch_card, f.focus)
			f.focus = next_adv
			vcard.focus_adv(switch_card, next_adv, true)
			track.focus(false)
			advancement.focus(card.adv_name(switch_card, f.focus), true)
			set_card_tips(switch_card, f)
			return true
		end
	end
	
	vdesktop.button_enable("button1", button)
	local function set_focus_adv(c)
		local obj = focus_adv[c]
		if obj then
			advancement.focus(card.adv_name(c, obj.focus), true)
			set_card_tips(c, obj)
		else
			vtips.set(nil)
		end
	end
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "button1" then
				vtips.set("tips.start.skip", button)
			else
				set_focus_adv(focus_state.object)
			end
		elseif focus_state.lost then
			vtips.set()
			track.focus(false)	-- disable all focus track
		end
		local switch_card, region = focus.click "right"
		if switch_card and focus_adv[switch_card] then
			if not change_next_focus_adv(switch_card) then
				-- unique adv, explain this card
				vtips.set()
				track.focus(false)
				show_desc.start {
					region = region,
					card = switch_card,
					adv_index = focus_adv[switch_card].focus,
				}
			end
		end
		local c, btn = focus.click "left"
		if c then
			if btn == "button1" then
				break
			end
			local obj = focus_adv[c]
			if obj then
				local adv_name = card.adv_name(c, obj.focus)
				track.focus(false)
				vtips.set(nil)
				
				local f = start_adv[adv_name]
				if f then	-- todo : 
					f()
				end
				use_adv(c, obj.focus)
				n, focus_adv = reset_cards_adv(advs)
				if not n then
					-- no more advs available
					break
				end
				track.focus(false)
				vtips.set(nil)
				set_focus_adv(c)	-- focus next adv
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
	set_card(advs, nil)
end

local function test_patch()
	test.patch "start"
	local hands = test.get_pile "hand"
	local diff = vdesktop.sync("hand", hands)
	if not diff then
		return
	end
	for _, c in ipairs(diff.discard) do
		print("START TEST DISCARD", c)
		vdesktop.transfer("hand", c, "deck")
		flow.sleep(5)
	end
	for _, c in ipairs(diff.draw) do
		print("START TEST DRAW", c)
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "hand")
		flow.sleep(5)
	end
end

local function discard_used_cards(advs)
	local cards = {}
	for _, adv in ipairs(advs) do
		if adv.use then
			cards[adv.card] = true
		end
	end
	for c in pairs(cards) do
		if card.pickup("hand", c) then
			card.discard(c)
			vdesktop.transfer("hand", c, "deck")
			flow.sleep(5)
		end
	end
end

return function ()
	test_patch()
	vdesktop.set_text("phase", "$(phase.start)")
	draw_hands()
	
--	persist.save "game.txt"

	local advs = card.find_stage("START", { "hand", "homeworld", "colony" })
	if #advs > 0 then
		choose_cards(advs)
		discard_used_cards(advs)
	end
	discard_hand_limit()

	return "action"
end
