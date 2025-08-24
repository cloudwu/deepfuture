local persist = require "gameplay.persist"
local card = require "gameplay.card"
local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local vcard = require "visual.card"
local focus = require "core.focus"
local vtips = require "visual.tips".layer "hud"
local vbutton = require "visual.button"
--local map = require "gameplay.map"
local show_desc = require "gameplay.desc"
local rules = require "core.rules".phase

global print, ipairs, pairs

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
		for _, adv in ipairs(advs) do
			if adv.enable then
				vcard.mask(adv.card, true)
				if adv.index == set[adv.card].focus then
					vcard.focus_adv(adv.card, adv.index, true)
				end
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
		local enable = card.check_adv(adv.name)
		adv.enable = enable
		if enable then
			n = n + 1
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

local function choose_cards(advs)
	local n = check_adv(advs)
	if n == 0 then
		return
	end
	local focus_adv = set_adv_focus(advs)
	set_card(advs, focus_adv)
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
	
	vdesktop.button_enable("button1", button)
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "button1" then
				vtips.set("tips.start.skip", button)
			else
				local c = focus_state.object
				local obj = focus_adv[c]
				if obj then
					set_card_tips(c, obj)
				else
					vtips.set(nil)
				end
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local switch_card, region = focus.click "right"
		if switch_card and focus_adv[switch_card] then
			local f = focus_adv[switch_card]
			local next_adv = find_next_adv(switch_card, f)
			if next_adv then
				vcard.focus_adv(switch_card, f.focus)
				f.focus = next_adv
				vcard.focus_adv(switch_card, next_adv, true)
				set_card_tips(switch_card, f)
			else
				-- unique adv, explain this card
				vtips.set()
				show_desc.start {
					region = region,
					card = switch_card,
					adv_index = f.focus,
				}
			end
		end
		local card, button = focus.click "left"
		if card then
			if button == "button1" then
				break
			end
			-- todo : adv effect
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	vtips.set(nil)
	set_card(advs, nil)
end

return function ()
	vdesktop.set_text("phase", "$(phase.start)")
	draw_hands()
	
--	persist.save "game.txt"

	local advs = card.find_stage("START", { "hand", "homeworld", "colony" })
	if #advs > 0 then
		choose_cards(advs)
	end
	-- todo : start effect
	discard_hand_limit()

	return "action"
end
