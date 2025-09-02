local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local rules = require "core.rules".phase
local card = require "gameplay.card"
local class = require "core.class"
local look = require "gameplay.look"
local advancement = require "gameplay.advancement"
local track = require "gameplay.track"
local vcard = require "visual.card"
local vtips = require "visual.tips".layer "hud"
local focus = require "core.focus"
local util = require "core.util"
local addadv = require "gameplay.addadv"
local table = table

global pairs, error, print, print_r, ipairs

local CARD_COPY <const> = "$(card.copy)"
local CHOOSE <const> = { phycics = true }
local REDRAW <const> = { chemistry = true }
local TRACK <const> = {
	engineering = true,
	philosophy = true,
	literature = true,
}

local adv_focus = {}

function adv_focus.engineering()
	vdesktop.draw_pile_focus(nil)
	track.focus("M", true)
end

function adv_focus.philosophy()
	vdesktop.draw_pile_focus(nil)
	track.focus("X", true)
end

function adv_focus.literature()
	vdesktop.draw_pile_focus(nil)
	track.focus("C", true)
end

local advance_adv = {}

function advance_adv.engineering()
	track.advance("M", 1)
end

function advance_adv.philosophy()
	track.advance("X", 1)
end

function advance_adv.literature()
	track.advance("C", 2)
end

local function interval()
	flow.sleep(20)
end

local function create_new()
	local newcard, card1, card2 = card.generate_newcard()
	local clone = { type = "blank" }
	
	vdesktop.add("deck", clone)
	vdesktop.transfer("deck", clone, "float")
	
	local function moving(c, f)
		vdesktop.add("deck", c)
		vdesktop.transfer("deck", c, "float")
		f()
		vcard.flush(clone)
		interval()
		vdesktop.transfer("float", c, "deck")
	end
	
	interval()

	moving(card1, function ()
		clone._marker = newcard.value
	end)
	
	moving(card2, function ()
		clone._marker = newcard._marker
	end)

	vdesktop.replace("float", clone, newcard)

	return newcard
end

local function add_suit(advs, c)
	local suit_card = card.draw_discard()
	vdesktop.add("deck", suit_card)
	vdesktop.transfer("deck", suit_card, "float")
	interval()
	local adv_index = card.add_adv_suit(c, suit_card.suit)
	vcard.flush(c)
	interval()
	vdesktop.transfer("float", suit_card, "deck")
	local n = advs:update(REDRAW)
	if n == 0 then
		vcard.mask(c)
		return adv_index
	end
	-- wait for redraw
	vcard.mask(c, true)
	c[adv_index]._name = "$(adv.random.confirm)"
	vcard.flush(c)

	local desc = {
		suit = card.suit_info(suit_card)
	}
	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			if focus_state.object == c then
				vtips.set("tips.advance.randsuit", desc)
			elseif advs:focus(focus_state.object) then
				vtips.set("tips.advance.chemistry", desc)
			else
				vtips.set("tips.advance.redraw", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local click_card, where = focus.click "left"
		if click_card == c then
			vtips.set()
			c[adv_index]._name = nil
			vcard.mask(c)
			vcard.flush(c)
			advs:reset()
			break
		elseif advs:focus(click_card) then
			vtips.set()
			advs:use(click_card)
			c[adv_index] = nil
			vcard.mask(c)
			vcard.flush(c)
			return add_suit(advs, c)
		elseif where == "discard" then
			vcard.mask(c)
			advs:look_drawpile()
			vcard.mask(c, true)
		end
		flow.sleep(0)
	end
	return adv_index
end

local function add_suits(c, advs)
	-- add 3 suits to c
	for i = 1, 3 do
		add_suit(advs, c)
	end
end

local function draw_new(advs)
	local c = card.draw_card() or error "No more card"
	vdesktop.add("deck", c)
	vdesktop.transfer("deck", c, "float")
	flow.sleep(5)
	if c.type == "tech" and not card.complete(c) then
		return c
	else
		if c.type ~= "blank" then
			card.discard(c)
			vdesktop.transfer("float", c, "deck")
			flow.sleep(5)
			c = create_new()
		end
		if c.type == "blank" then
			interval()
			card.blank_tech(c)
		end
		vtips.set()
		add_suits(c, advs)
		return c
	end
end

local function choose_physics(c)
	local choose = addadv.choose_random_adv(c)
	local n = #choose
	addadv.add_choice(choose)
	return table.move(choose, n+1, n*2, 1, {})
end

local function choose_or_random(random_value_choice, advs, need_physics)
	vtips.set()
	vcard.mask(random_value_choice, true)
	vcard.flush(random_value_choice)
	local focus_state = {}
	local desc = { n = need_physics }
	local random_value_choice_float = true
	while true do
		if focus.get(focus_state) then
			if random_value_choice_float and focus_state.object == random_value_choice then
				vtips.set("tips.advance.physics.nouse")
			elseif advs:focus(focus_state.object) then
				vtips.set("tips.advance.physics.use", desc)
			else
				vtips.set("tips.advance.physics.need", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local click_card, where = focus.click "left"
		if random_value_choice_float and click_card == random_value_choice then
			-- choose random
			vtips.set()
			advs:reset()
			vdesktop.transfer("float", random_value_choice, "deck")
			flow.sleep(5)
			return addadv.choose_random_adv(random_value_choice)
		elseif advs:focus(click_card) then
			vtips.set()
			advs:use(click_card)
			need_physics = need_physics - 1
			if random_value_choice_float then
				vcard.mask(random_value_choice)
				random_value_choice[random_value_choice._random]._name = "$(adv.choose.value)"
				vcard.flush(random_value_choice)
				random_value_choice_float = false
			end
			if need_physics == 0 then
				advs:reset()
				vdesktop.transfer("float", random_value_choice, "deck")
				flow.sleep(5)
				vcard.mask(random_value_choice)
				return choose_physics(random_value_choice)
			else
				advs:update(CHOOSE)
				desc.n = need_physics
			end
		elseif where == "discard" then
			vcard.mask(random_value_choice)
			advs:look_drawpile()
			vcard.mask(random_value_choice, true)
		end
		flow.sleep(0)
	end
end

local function gen_choose_cards(c, advs)
	local choose = addadv.choose_random_adv(c)
	if c.type == "tech" then
		local chosen = card.chosen(c)	-- need chosen of physics
		-- world card can't choose
		if chosen == 0 then
			-- first choice
			addadv.add_choice(choose)
		else
			-- need physics
			local n = advs:update(CHOOSE)
			if n < chosen then
				-- not enough physics, only random choice
				if n > 0 then
					advs:reset()
				end
			else
				-- enough physics, only one choose card
				local random_clone = choose[1] 
				for i = 2, #choose do
					local c = choose[i]
					local adv_index = c._random
					random_clone[adv_index] = c[adv_index]
					choose[i] = nil
				end
				vdesktop.replace("float", c, random_clone)
				local choose = choose_or_random(random_clone, advs, chosen)
				vdesktop.replace("float", random_clone, c)
				return choose
			end
		end
	end
	return choose
end

local function draw_value(advs, c, adv_index)
	local value_card = card.draw_discard()
	vdesktop.add("deck", value_card)
	vdesktop.transfer("deck", value_card, "float")
	interval()
	c[adv_index].value = value_card.value
	c[adv_index].era = c.era
	card.gen_desc(c)
	vcard.flush(c)
	interval()
	vdesktop.transfer("float", value_card, "deck")
	local n = advs:update(REDRAW)
	if n == 0 then
		return
	end
	-- wait for redraw
	vcard.mask(c, true)
	local adv = c[adv_index]
	local adv_name = advancement.name(adv.suit, adv.value)
	local adv_info = advancement.info(adv_name, "name")
	adv._name = adv_info .. " $(adv.random.confirm)"
	vcard.flush(c)

	local desc = {
		name = adv_info,
		desc = advancement.info(adv_name, "desc"),
		adv = "$(tips.adv." .. c[adv_index].suit .. ".choice)"
	}
	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			if focus_state.object == c then
				vtips.set("tips.advance.randvalue", desc)
			elseif advs:focus(focus_state.object) then
				vtips.set("tips.advance.chemistry.value", desc)
			else
				vtips.set("tips.advance.redraw.value", desc)
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local click_card, where = focus.click "left"
		if click_card == c then
			vtips.set()
			adv._name = nil
			card.gen_desc(c)
			vcard.mask(c)
			vcard.flush(c)
			advs:reset()
			break
		elseif advs:focus(click_card) then
			vtips.set()
			advs:use(click_card)
			vcard.mask(c)
			return draw_value(advs, c, adv_index)
		elseif where == "discard" then
			vcard.mask(c)
			advs:look_drawpile()
			vcard.mask(c, true)
		end
		flow.sleep(0)
	end
	return adv_index
end

local function advance_world(c, advs)
	-- add a random suit
	local adv_index = add_suit(advs, c)
	draw_value(advs, c, adv_index)
end

local function advance(c, advs)
	if c.type == "world" then
		advance_world(c, advs)
		return
	end
	local choose = gen_choose_cards(c, advs)
	if #choose == 1 then
		-- only one choice
		local clone = choose[1]
		local adv_index = clone._random
		if adv_index then
			-- draw value
			draw_value(advs, c, adv_index)
			advs:reset()
			flow.sleep(5)
			return
		end
		-- phycics choose
		addadv.choose_value(c, clone._choose)
		return
	end
	local click_card = addadv.choose_or_random(choose, c, advs)

	local adv_index = click_card._random
	if adv_index then
		-- draw card
		draw_value(advs, c, adv_index)
		advs:reset()
		flow.sleep(5)
	elseif click_card._choose then
		-- choose adv
		addadv.choose_value(c, click_card._choose)
	end
end

local function find_uncomplete(where, r)
	local n = 1
	while true do
		local c = card.card(where, n)
		if not c then
			return r
		end
		if not card.complete(c) then
			r[c] = true
		end
		n = n + 1
	end
end

local function unmask(cards)
	for c in pairs(cards) do
		vcard.mask(c)
	end
	vdesktop.draw_pile_focus()
end

return function(extra)
	local phase_desc = { extra = "[blue]$(ADVANCE)[n]" }
	if extra then
		phase_desc.extra = extra .. phase_desc.extra
	end
	vdesktop.set_text("phase", phase_desc)
	local cards = find_uncomplete("homeworld", {})
	find_uncomplete("colony", cards)
	for c in pairs(cards) do
		vcard.mask(c, true)
	end
	vdesktop.draw_pile_focus(true)
	
	local focus_state = {}
	
	local advs = class.effect "ADVANCE"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"
	
	local advcard

	while true do
		if focus.get(focus_state) then
			if focus_state.active == "discard" then
				vtips.set "tips.advance.newcard"
			elseif cards[focus_state.object] then
				vtips.set "tips.advance.card"
			else
				vtips.set "tips.advance.invalid"
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c, where = focus.click "left"
		if c then
			if where == "discard" then
				unmask(cards)
				local newcard = draw_new(advs)
				advance(newcard, advs)
				advcard = newcard
				card.putdown("homeworld", newcard)
				vdesktop.transfer("float", newcard, "homeworld")
				break
			elseif cards[c] then
				-- clone a copy for adv using
				unmask(cards)
				local clone = util.shallow_clone(c, {})
				c.name = CARD_COPY
				vcard.flush(c)
				vdesktop.replace(where, c, clone)
				vdesktop.transfer(where, clone, "float")
				vdesktop.add(where, c)
				flow.sleep(5)
				advance(clone, advs)
				vdesktop.remove(where, c)
				c.adv1 = clone.adv1
				c.adv2 = clone.adv2
				c.adv3 = clone.adv3
				c.name = clone.name
				vcard.flush(c)
				advcard = c
				vdesktop.replace("float", clone, c)
				vdesktop.transfer("float", c, where)
				flow.sleep(5)
				break
			end
		end
		flow.sleep(0)
	end
	-- advance done, any advancement ?
	local n = advs:update(TRACK)
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "advance",
			adv_focus = adv_focus,
			adv_func = advance_adv,
			adv_select = TRACK,
		}
		advs:discard_used_cards()
	end
	
	advs:add(advcard)
	advs:reset()
	vcard.mask(advcard)
end
