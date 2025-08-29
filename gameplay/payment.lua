local vdesktop = require "visual.desktop"
local flow = require "core.flow"
local vtips = require "visual.tips".layer "hud"
local vcard = require "visual.card"
local card = require "gameplay.card"
local rules = require "core.rules".phase
local focus = require "core.focus"
local vdesktop = require "visual.desktop"

local UPKEEP_LIMIT <const> = rules.payment.upkeep_limit

global pairs, print, ipairs, print_r, error, next, print_r

local function payment(homeworld_card)
	local challenge_card
	vcard.mask(homeworld_card, true)
	local suits = card.adv_suits(homeworld_card)
	local need_suits = card.payment_text(homeworld_card)
	local cards = card.find_suit("colony", suits, {})
	card.find_suit("hand", suits, cards)
	for c in pairs(cards) do
		vcard.mask(c, true)
	end
	local upkeep_n = card.upkeep(homeworld_card)
	local focus_state = {}
	local desc = {
		need_suits = need_suits,
		cardtype = "$(card.type." .. homeworld_card.type .. ")",
	}
	local nochoice = next(cards) == nil
	if nochoice then
		desc.nochoice = "$(tips.payment.nochoice)"
	else
		desc.choice = "$(tips.payment.choice)"
	end
	
	if upkeep_n < UPKEEP_LIMIT then
		desc.upkeep = "$(tips.payment.upkeep)"
	end
	while true do
		if focus.get(focus_state) then
			if focus_state.object == homeworld_card then
				vtips.set ("tips.payment.skip", desc)
			elseif cards[focus_state.object] then
				desc.suit = card.suit_info(focus_state.object)
				desc.cardfrom = "$(desc.place." .. focus_state.active .. ")"
				vtips.set ("tips.payment.use", desc)
			elseif nochoice then
				vtips.set ()
			else
				vtips.set ("tips.payment.invalid", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c, where = focus.click "left"
		if c == homeworld_card then
			-- add challenge card
			challenge_card = card.draw_card()
			break
		elseif cards[c] then
			-- use
			card.pickup(where, c)
			card.discard(c)
			vdesktop.transfer(where, c, "deck")
			card.upkeep_change(homeworld_card, 1)
			vcard.flush(homeworld_card)
			break
		end
		flow.sleep(0)
	end

	for c in pairs(cards) do
		vcard.mask(c)
	end
	vcard.mask(homeworld_card)
	
	return challenge_card
end

local function add_challenge(challenge_card)
	card.putdown("challenge", challenge_card)
	local back = { type = "back", text = "$(card.challenge)" }
	challenge_card._back = back
	vdesktop.add("deck", back)
	vdesktop.transfer("deck", back, "colony")
end

return function ()
	vdesktop.set_text("phase", "$(phase.payment)")
	local n = 1
	while true do
		local c = card.card("homeworld", n)
		if c == nil then
			break
		end
		n = n + 1
		flow.sleep(0)
		local challenge_card = payment(c)
		vtips.set()
		if challenge_card then
			add_challenge(challenge_card)
		end
	end
	for i = 1, rules.payment.least do
		local c = card.draw_card()
		add_challenge(c)
	end
	return "idle"
end
