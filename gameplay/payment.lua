local vdesktop = require "visual.desktop"
local flow = require "core.flow"
local vtips = require "visual.tips".layer "hud"
local vcard = require "visual.card"
local card = require "gameplay.card"
local rules = require "core.rules".phase
local mouse = require "core.mouse"
local vdesktop = require "visual.desktop"
local look = require "gameplay.look"
local sync = require "gameplay.sync"
local loadsave = require "core.loadsave"
local ui = require "core.rules".ui
local desktop = require "gameplay.desktop"

local UPKEEP_LIMIT <const> = rules.payment.upkeep_limit

global pairs, print, ipairs, print_r, error, next, print_r

local function payment(homeworld_card)
	local challenge_card
	local suits = card.adv_suits(homeworld_card)
	local need_suits = card.payment_text(homeworld_card)
	local cards = card.find_suit("hand", suits, {})
	
	local confirm = desktop.confirm(homeworld_card, cards)
	confirm:set_mask(true)
	
	local upkeep_n = card.upkeep(homeworld_card)
	local focus_state = {}
	local desc = {
		need_suits = need_suits,
		cardtype = "$(card.type." .. homeworld_card.type .. ")",
	}
	if confirm.warning then
		desc.choice = "$(tips.payment.choice)"
	else
		desc.nochoice = "$(tips.payment.nochoice)"
	end
	
	if upkeep_n < UPKEEP_LIMIT then
		desc.upkeep = "$(tips.payment.upkeep)"
	end
	while true do
		if mouse.get(focus_state) then
			confirm.notice = focus_state.object == homeworld_card
			if confirm.notice then
				vtips.set ("tips.payment.skip", desc)
			elseif cards[focus_state.object] then
				desc.suit = card.suit_info(focus_state.object)
				desc.cardfrom = "$(desc.place." .. focus_state.active .. ")"
				vtips.set ("tips.payment.use", desc)
			elseif confirm.warning then
				vtips.set ("tips.payment.invalid", desc)
			else
				vtips.set ()
			end
		elseif focus_state.active == "discard" then
			desc.seen = card.seen()
			if desc.seen > 0 then
				vtips.set("tips.look.pile", desc)
			end
		elseif not focus_state.object then
			vtips.set()
		end
		local c, where = mouse.click(focus_state, "left")
		if c == homeworld_card and confirm:click() then
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
		elseif where == "discard" then
			confirm:set_mask()
			local n = card.seen()
			if n > 0 then
				look.start(n, focus_state)
			end
			confirm:set_mask(true)
		end
		confirm:update()
		flow.sleep(0)
	end

	confirm:set_mask()

	return challenge_card
end

local function add_challenge(challenge_card)
	card.putdown("challenge", challenge_card)
	local back = { type = "back", text = "$(card.challenge)", _challenge = challenge_card }
	challenge_card._back = back
	vdesktop.add("deck", back)
	vdesktop.transfer("deck", back, "colony")
	flow.sleep(5)
end

return function ()
	loadsave.sync_game "payment"
	sync()
	vdesktop.set_text("phase", { text = "$(phase.payment)", extra = false })
	local n = 1
	local backs = {}
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
			backs[#backs+1] = challenge_card._back
		end
	end
	for i = 1, rules.payment.least do
		flow.sleep(5)
		local c = card.draw_card()
		add_challenge(c)
		backs[#backs+1] = c._back
	end
	
	-- wait for moving
	repeat
		local moving
		for _, c in ipairs(backs) do
			moving = moving or vdesktop.moving("colony", c)
			flow.sleep(0)
		end
	until not moving
	
	return flow.state.challenge
end
