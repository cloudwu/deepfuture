local advancement = require "gameplay.advancement"
local vcard = require "visual.card"
local card = require "gameplay.card"
local class = require "core.class"
local vdesktop = require "visual.desktop"
local flow = require "core.flow"
local look = require "gameplay.look"
local vtips = require "visual.tips".layer "hud"
local focus = require "core.focus"
local track = require "gameplay.track"
local show_desc = require "gameplay.desc"
local vbutton = require "visual.button"
local map = require "gameplay.map"

global setmetatable, pairs, assert, print, ipairs, error

local effect = class.container "effect"

function effect:add(c, from)
	if from == "hand" and (c.type ~= "tech" or not card.complete(c)) then
		return
	end
	self:remove(c)
	local obj = {}
	self[c] = obj
	local stage = self[false]
	for i = 1, 3 do
		local adv = c["adv"..i]
		if adv and adv.value then
			local name = advancement.name(adv.suit, adv.value)
			if advancement.stage(adv.suit, adv.value) == stage then
				obj[i] = {
					name = name,
					enable = true,
					use = false,
				}
			end
		else
			obj[i] = false
		end
	end
end

function effect:add_pile(from)
	local n = 1
	while true do
		local c = card.card(from, n)
		if c == nil then
			return
		end
		self:add(c, from)
		n = n + 1
	end
end

function effect:remove(c)
	local obj = self[c]
	if obj == nil then
		return
	end
	self[c] = nil
	vcard.mask(c)
	for i = 1, 3 do
		if obj[i] then
			vcard.focus_adv(c, i)
		end
	end
end

function effect:focus(c)
	local obj = self[c]
	if not obj then
		return
	end
	local focus = obj.focus
	if not focus then
		return
	end
	return obj[focus].name
end

function effect:update(select_adv)
	local tmp = {}
	local n = 0
	for c, adv in pairs(self) do
		tmp[c] = false
		for index = 1, 3 do
			local obj = adv[index]
			if obj then
				if obj.use then
					vcard.focus_adv(c, index, false)
					if adv.focus == index then
						adv.focus = nil
					end
				else
					local enable
					if select_adv == nil or select_adv[obj.name] then
						enable = self:check_adv(obj.name, c)
					else
						enable = false
					end
					obj.enable = enable
					if enable then
						n = n + 1
						tmp[c] = index
					end
					vcard.focus_adv(c, index, nil)
				end
			end
		end
	end
	
	for c, index in pairs(tmp) do
		if index then
			vcard.mask(c, true)
			self[c].focus = index
			vcard.focus_adv(c, index, true)
		else
			vcard.mask(c)
		end
	end
	return n
end

local order <const> = {
	{ 2, 3 },	-- next 1
	{ 3, 1 },	-- next 2
	{ 1, 2 },	-- next 3
}

local function next_adv(self, c)
	local obj = self[c]
	local focus = obj.focus
	for i = 1, 2 do
		local idx = order[focus][i]
		local n = obj[idx]
		if n and n.enable then
			return idx
		end
	end
end

function effect:use(c)
	local obj = self[c]
	local current = obj[obj.focus]
	current.use = true
	current.enable = false
	vcard.focus_adv(c, obj.focus, false)
	local n = next_adv(self, c)
	if n then
		obj.focus = n
		vcard.focus_adv(c, n, true)
	else
		vcard.mask(c)
		obj.focus = nil
	end
end

local function next_unique(self, c)
	local obj = self[c]
	if obj == nil then
		return
	end
	local focus = obj.focus
	if focus == nil then
		return
	end
	local name = obj[focus].name
	for i = 1, 2 do
		local idx = order[focus][i]
		local n = obj[idx]
		if n and n.enable and n.name ~= name then
			return idx
		end
	end
end

function effect:nextadv(c, switch)
	local n = next_unique(self, c)
	if n then
		if switch then
			vcard.focus_adv(c, self[c].focus, nil)
			vcard.focus_adv(c, n, true)
			self[c].focus = n
		end
		return self[c][n].name
	end
end

local function reset_enable(self)
	local tmp = {}
	local n = 0
	for c, adv in pairs(self) do
		tmp[c] = false
		for index = 1, 3 do
			local obj = adv[index]
			if obj then
				if obj.use then
					vcard.focus_adv(c, index, false)
					if adv.focus == index then
						adv.focus = nil
					end
				else
					local enable = obj.enable
					if enable then
						n = n + 1
						tmp[c] = index
					end
					vcard.focus_adv(c, index, nil)
				end
			end
		end
	end
	
	for c, index in pairs(tmp) do
		if index then
			vcard.mask(c, true)
			self[c].focus = index
			vcard.focus_adv(c, index, true)
		else
			vcard.mask(c)
		end
	end
	return n
end


function effect:reset(enable)
	if enable then
		reset_enable(self)
	else
		for c in pairs(self) do
			vcard.mask(c)
			vcard.focus_adv(c, 1)
			vcard.focus_adv(c, 2)
			vcard.focus_adv(c, 3)
		end
	end
end

function effect:used_cards(cards)
	cards = cards or {}
	for c, obj in pairs(self) do
		for i = 1, 3 do
			local adv = obj[i]
			if adv and adv.use then
				cards[c] = true
			end
		end
	end
	return cards
end

function effect:is_used(c)
	local obj = self[c]
	if not obj then
		return
	end
	for i = 1, 3 do
		local adv = obj[i]
		if adv and adv.use then
			return true
		end
	end
end

function effect:can_use(c)
	local obj = self[c]
	if obj == nil then
		return
	end
	return self[c].focus
end

function effect:discard_used_cards()
	local cards = self:used_cards()
	for c in pairs(cards) do
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
	self:reset()
end

function effect:look_drawpile(button)
	local n = card.seen()
	if n == 0 then
		return
	end
	if button then
		vdesktop.button_enable("button1", nil)
	end
	self:reset()
	look.start(n)
	self:reset(true)
	if button then
		vdesktop.button_enable("button1", button)
	end
end

local function advancement_unfocus()
	vdesktop.draw_pile_focus(nil)
	track.focus(false)	-- disable all focus track
end

local function advancement_focus(f)
	if f then
		f()
	else
		advancement_unfocus()
	end
end

function effect:choose_cards(args)
	local adv_focus = args.adv_focus
	local adv_func = args.adv_func
	local adv_select = args.adv_select
	local map_message = args.map_message
	local button = {
		text = "button.advancement.skip",
		n = args.n,
		phase = "$(tips.advancement." .. args.phase .. ")",
	}
	local desc = {
		seen = nil,
	}
	local card_tips = {}
	local focus_state = {}
	
	vdesktop.button_enable("button1", button)
				
	local function update_adv()
		local n = self:update(adv_select)
		if n == 0 then
			-- no more advs available
			return true
		end
		if n ~= button.n then
			button.n = n
			vbutton.update "button1"
		end
	end
	
	while true do
		if focus.get(focus_state) then
			local where = focus_state.active
			if where == "button1" then
				vtips.set("tips.advancement.skip", button)
			elseif where == "discard" then
				desc.seen = card.seen()
				if desc.seen > 0 then
					vtips.set("tips.look.pile", desc)
				end
			elseif where == "map" and map_message then
				map_message.focus(focus_state.object)
			else
				local focus = self:focus(focus_state.object)
				if focus then
					advancement_focus(adv_focus[focus])
					card_tips.adv = advancement.info(focus, "name")
					card_tips.effect = advancement.info(focus, "desc")
					local next_adv = self:nextadv(focus_state.object)
					if next_adv then
						card_tips.nextadv = advancement.info(next_adv, "name")
						vtips.set("tips.advancement.card.multiple", card_tips)
					else
						vtips.set("tips.advancement.card.unique", card_tips)
					end
				else
					vtips.set()
				end
			end
		elseif focus_state.lost then
			vtips.set()
			advancement_unfocus()
		end
		local switch_card, region = focus.click "right"
		if switch_card then
			if self:can_use(switch_card) then
				local focus = self:nextadv(switch_card, true)
				if not focus then
					-- unique adv, explain this card
					vtips.set()
					advancement_unfocus()
					show_desc.start {
						region = region,
						card = switch_card,
						name = self:focus(switch_card),
					}
				else
					advancement_focus(adv_focus[focus])
					card_tips.adv = advancement.info(focus, "name")
					card_tips.effect = advancement.info(focus, "desc")
					local next_adv = self:nextadv(focus_state.object)
					card_tips.nextadv = advancement.info(next_adv, "name")
					vtips.set("tips.advancement.card.multiple", card_tips)
				end
			end
		end
		local c, btn = focus.click "left"
		if c then
			if btn == "button1" then
				self:reset()
				break
			elseif btn == "map" and map_message then
				map_message.click(c, "left")
				if update_adv() then
					break
				end
			elseif self:can_use(c) then
				advancement_unfocus()
				vtips.set(nil)
				local adv_name = self:focus(c)
				self:use(c)
				vdesktop.button_enable("button1", nil)
				local f = adv_func[adv_name] or ("Unknown adv : " .. adv_name)
				-- do adv
				f(self)
				vdesktop.button_enable("button1", button)
				if update_adv() then
					break
				end
				advancement_unfocus()
				vtips.set(nil)
			elseif btn == "discard" then
				self:look_drawpile(button)
			else
				vtips.set(nil)
			end
		end
		if map_message then
			local c, where = focus.click "right"
			if where == "map" then
				map_message.click(c, "right")
				if update_adv() then
					break
				end
			end
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	vtips.set(nil)
	flow.sleep(1)
end

function effect:discard_one_card(phase, advname, action)
	vdesktop.set_text("phase", {
		text = "$(phase.discard)",
		extra = "[blue]$(adv." .. advname .. ".name)[n]",
	})
	local discards = {}
	local n = 1
	while true do
		local c = card.card("hand", n)
		if c == nil then
			break
		end
		if not self:is_used(c) then
			discards[#discards+1] = c
		end
		n = n + 1
	end
	self:reset()
	for _, c in ipairs(discards) do
		vcard.mask(c, true)
	end
	local focus_state = {}
	while true do
		if focus.get(focus_state) then
			if focus_state.active == "hand" then
				if self:is_used(focus_state.object) then
					vtips.set "tips.discard.advancement.invalid"
				else
					vtips.set "tips.discard.advancement"
				end
			else
				vtips.set()
			end
		elseif focus_state.lost then
			vtips.set()
		end
		local c = focus.click "left"
		if c and not self:is_used(c) then
			local discard_card = card.pickup("hand", c)
			if discard_card then
				card.discard(discard_card)
				vdesktop.set_text("phase", { text = "$(phase." .. phase .. ")", extra = action })
				for _, c in ipairs(discards) do
					vcard.mask(c)
				end
				self:remove(discard_card)
				vdesktop.transfer("hand", discard_card, "deck")
				vtips.set()
				break
			end
		end
		flow.sleep(0)
	end
	flow.sleep(1)
end

local function check_any_track()
	return track.check("C", -1) or track.check("M", -1) or track.check("S", -1) or track.check("X", -1)
end

local adv_check = {}

-- START
function adv_check.computation(draw_pile, discard_pile)
	local n = card.count "draw" + card.count "discard"
	return n > 0
end

function adv_check.art()
	return track.check("C", 1)
end

function adv_check.infrastructure()
	-- inject from core.card
	if advancement._upkeep_full() then
		return false
	end
	return check_any_track()
end

function adv_check.history()
	return card.count "draw" - card.seen() > 0
end

function adv_check.economy()
	local n = card.count "draw" + card.count "discard"
	return check_any_track() and n > 0
end

function adv_check.exploration()
	local r = map.can_move()
	return r
end

--POWER
function adv_check.industry(advs, current_card)
	local n = 1
	while true do
		local c = card.card("hand", n)
		if c == nil then
			break
		end
		if not advs:is_used(c) and c ~= current_card then
			return true
		end
		n = n + 1
	end
	return false
end

function adv_check.energy()
	local n = card.count "draw" + card.count "discard"
	return n > 0
end

function adv_check.labor()
	return track.check("S", 1)
end

function adv_check.empire()
	return track.check("M", 1)
end

function adv_check.devices()
	return track.check("C", 2)
end

-- ADVANCE
function adv_check.chemistry()
	return true
end

function adv_check.physics()
	return true
end

function adv_check.philosophy()
	return track.check("X", 1)
end

function adv_check.literature()
	return track.check("C", 2)
end

function adv_check.engineering()
	return track.check("M", 1)
end

-- GROW
function adv_check.biology()
	return not not map.can_grow_extra()
end

function adv_check.genetics()
	return map.can_grow_more()
end

function adv_check.education()
	return track.check("X", 1)
end

function adv_check.agriculture()
	return track.check("S", 1)
end

function adv_check.construction()
	return track.check("C", 2)
end

-- SETTLE
function adv_check.leisure()
	return track.check("C", 2)
end

function adv_check.government()
	local c = card.settling()
	return not card.complete(c)
end

function adv_check.society()
	return card.settling() == nil
end

function adv_check.medicine()
	return track.check("S", 1)
end

function adv_check.ecology()
	return track.check("X", 1)
end

-- BATTLE
function adv_check.weapons()
	return track.check("M", 1)
end

function adv_check.machinery()
	return track.check("S", 1)
end

function adv_check.diplomacy()
	return track.check("C", 2)
end

function adv_check.military()
	return not map.is_safe()
end

function adv_check.defense()
	local extra = map.hostile()
	if extra == nil then
		return false
	end
	local neutral, neutral_n, player, player_n = map.battlefield()
	return extra < neutral_n
end

function effect:check_adv(adv_name, c)
	local f = adv_check[adv_name] or error ("Invalid adv " .. adv_name)
	return f(self, c)
end

function class.effect(action)
	return effect {
		[false] = action,
	}
end
