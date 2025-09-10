local util = require "core.util"
local card = require "gameplay.card"
local vdesktop = require "visual.desktop"
local flow = require "core.flow"
local vcard = require "visual.card"
local vtips = require "visual.tips".layer "hud"
local advancement = require "gameplay.advancement"
local mouse = require "core.mouse"

global ipairs, pairs

local CARD_COPY <const> = "$(card.copy)"

local addadv = {}

local function add_random_choice(c, adv_index, r)
	local adv = c[adv_index]
	if adv == nil or adv.value then
		return
	end
	adv._name = nil
	local clone = util.shallow_clone(c, {})
	clone.name = CARD_COPY
	clone[adv_index] = util.shallow_clone(adv, { _name = "$(adv.random.value)" })
	clone._random = adv_index
	r[#r+1] = clone
end

function addadv.choose_random_adv(c)
	local choose = {}
	add_random_choice(c, "adv1", choose)
	add_random_choice(c, "adv2", choose)
	add_random_choice(c, "adv3", choose)
	return choose
end

function addadv.add_choice(choose)
	local n = #choose
	for i = 1, n do
		local c = choose[i]
		local clone = util.shallow_clone(c, {})
		local adv_index = clone._random
		clone._random = nil
		clone[adv_index] = util.shallow_clone(c[adv_index], { chosen = true })
		card.gen_desc(clone)
		clone[adv_index]._name = "$(adv.choose.value)"
		clone._choose = adv_index
		choose[n+i] = clone
	end
end

function addadv.choose_or_random(choose, c, advs)
	vdesktop.transfer("float", c, "deck")
	for _, copy in ipairs(choose) do
		vcard.mask(copy, true)
	end
	for i = 1, #choose do
		vdesktop.add("deck", choose[i])
		vdesktop.transfer("deck", choose[i], "float")
		flow.sleep(5)
	end
	
	-- choose random or choose value
	local focus_state = {}
	local desc = {}
	
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "float" then
				local copy = focus_state.object
				local adv_index = copy._random
				if adv_index then
					-- random adv
					local adv = copy[adv_index]
					desc.suit = card.suit_info(adv)
					desc.adv = "$(tips.adv."..adv.suit..".choice)"
					vtips.set ("tips.advance.random", desc)
				else
					adv_index = copy._choose
					if adv_index then
						desc.suit = card.suit_info(copy[adv_index])
						vtips.set ("tips.advance.choose", desc)
					end
				end
			elseif focus_state.object then
				vtips.set ("tips.advance.choose.invalid", desc)
			else
				vtips.set ()
			end
		end
		local click_card, where = mouse.click(focus_state, "left")
		if click_card then
			if where == "discard" and card.seen() > 0 then
				vtips.set()
				for _, c in ipairs(choose) do
					flow.sleep(1)
					vdesktop.transfer("float", c, "deck")
				end
				advs:look_drawpile(focus_state)
				for _, c in ipairs(choose) do
					flow.sleep(1)
					vdesktop.add("deck", c)
					vdesktop.transfer("deck", c, "float")
				end
			elseif where == "float" then
				vtips.set()
				-- drop copies expert chosen one
				for _, tmp in ipairs(choose) do
					if tmp ~= click_card then
						vcard.mask(tmp)
						vdesktop.transfer("float", tmp, "deck")
					end
					flow.sleep(5)
				end
				vdesktop.replace("float", click_card, c)
				flow.sleep(5)
				return click_card
			end
		end
		flow.sleep(0)
	end
end

function addadv.choose_value(c, adv_index)
	vdesktop.transfer("float", c, "deck")
	flow.sleep(5)
	local cards = {}
	local adv_suit = c[adv_index].suit
	local adv_era = c[adv_index].era
	for i = 1, 6 do
		local clone = util.shallow_clone(c, {})
		clone.name = CARD_COPY
		local adv = {
			suit = adv_suit,
			value = i,
			era = c.era,
			chosen = i,
		}
		
		clone[adv_index] = adv
		card.gen_desc(clone)
		adv._circle = "[blue][circle][n]"
		cards[clone] = true
		vdesktop.add("deck", clone)
		vdesktop.transfer("deck", clone, "float")
		flow.sleep(5)
		vcard.mask(clone, true)
	end

	local focus_state = {}
	local desc = { suit = card.suit_info(c[adv_index]) }
	while true do
		if mouse.get(focus_state) then
			if cards[focus_state.object] then
				local adv = focus_state.object[adv_index]
				local adv_name = advancement.name(adv.suit, adv.value)
				desc.name = advancement.info(adv_name, "name")
				desc.desc = advancement.info(adv_name, "desc")
				vtips.set("tips.advance.physics.confirm", desc)
			elseif focus_state.object then
				vtips.set("tips.advance.physics.invalid", desc)
			else
				vtips.set()
			end
		end
		local clone = mouse.click(focus_state, "left")
		if cards[clone] then
			vtips.set()
			for tmp in pairs(cards) do
				if tmp ~= clone then
					vcard.mask(tmp)
					vdesktop.transfer("float", tmp, "deck")
				end
				flow.sleep(5)
			end
			flow.sleep(20)
			c[adv_index].value = clone[adv_index].value
			c[adv_index].era = clone.era
			c[adv_index].chosen = true
			card.gen_desc(c)
			vcard.flush(c)
			vdesktop.replace("float", clone, c)
			flow.sleep(5)
			return
		end
		flow.sleep(0)
	end
end

return addadv
