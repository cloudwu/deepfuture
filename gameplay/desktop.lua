local card = require "gameplay.card"
local vdesktop = require "visual.desktop"
local mouse = require "core.mouse"
local flow = require "core.flow"
local vtips = require "visual.tips".layer "hud"
local track = require "gameplay.track"
local vcard = require "visual.card"
local map = require "core.mouse"
local color = require "visual.color"
local ui = require "core.rules".ui

global assert, ipairs, pairs, setmetatable, next, print

local desktop = {}

local function wait_moving(where, c)
	repeat
		flow.sleep(1)
	until not vdesktop.moving(where, c)
end

function desktop.move_to_neutral(c, from)
	card.upkeep_change(c)	-- clear upkeep
	vdesktop.transfer(from, c, "neutral")
	local last = card.find_value("neutral", c.value)
	if last then
		last = card.pickup("neutral", last)
		card.discard(last)
		vdesktop.transfer("neutral", last, "deck")
	end
	card.putdown("neutral", c)
	wait_moving("neutral", c)
end

function desktop.relocate_homeworld(homeworld)
	vtips.set()
	desktop.move_to_neutral(homeworld, "homeworld")
	local colony = card.pile "colony"
	if #colony == 0 then
		return
	end
	for _, c in ipairs(colony) do
		vcard.mask(c, true)
	end
	vdesktop.set_text("phase", { extra = "$(tips.challenge.relocate)" })
	local focus_state = {}
	local new_homeworld
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "colony" then
				vtips.set "tips.homeworld.set"
			elseif focus_state.object then
				vtips.set "tips.homeworld.invalid"
			else
				vtips.set()
			end
		end
		local sec, region = mouse.click(focus_state, "left")
		if sec and region == "colony" then
			new_homeworld = card.pickup("colony", sec)
			break
		end
		flow.sleep(0)
	end
	for _, c in ipairs(colony) do
		vcard.mask(c)
	end
	card.putdown("homeworld", new_homeworld)
	vdesktop.transfer("colony", new_homeworld, "homeworld")
	vtips.set()
	flow.sleep(5)
	return true
end

function desktop.check_lost(lost)
	if not lost then
		return track.loss()
	end
	local colony_sector = {}
	local n = 1
	while true do
		local c = card.card("colony", n)
		if c == nil then
			break
		end
		n = n + 1
		local list = colony_sector[c.sector] or {}
		colony_sector[c.sector] = list
		list[#list+1] = c
	end
	-- discard colony
	for sector in pairs(lost) do
		local list = colony_sector[sector]
		if list then
			for _, c in ipairs(list) do
				c = card.pickup("colony", c)
				card.discard(c)
				vdesktop.transfer("colony", c , "deck")
				flow.sleep(5)
			end
		end
	end
	local homeworld = card.card("homeworld", 1)
	assert(homeworld and homeworld.type == "world")
	if lost[homeworld.sector] then
		-- lost homeworld
		local c = card.pickup("homeworld", homeworld)
		if not desktop.relocate_homeworld(c) then
			vtips.set()
			return true
		end
	end
	return track.loss()
end

local DURATION <const> = ui.focus.duration
local WARNING_MASK <const> = ui.card.mask_warning
local COLOR <const> = color.blend(ui.card.mask_normal, ui.card.mask_focus)

local confirm = {}; confirm.__index = confirm

function confirm:set_mask(flag)
	if self.warning then
		if flag then
			vcard.mask(self.confirm_card, WARNING_MASK)
		else
			vcard.mask(self.confirm_card, flag)
		end
		for c in pairs(self.cards) do
			vcard.mask(c, flag)
		end
	else
		vcard.mask(self.confirm_card, flag)
	end
end

function confirm:click()
	return not self.warning or self.confirm_duration >= DURATION
end

function confirm:update()
	if mouse.press("left", self.confirm_card) then
		self.confirm_duration = self.confirm_duration + 1
		if self.confirm_duration > DURATION then
			self.confirm_duration = DURATION
		end
	else
		self.confirm_duration = self.confirm_duration - 1
		if self.confirm_duration <= 0 then
			self.confirm_duration = 0
		end
	end
	if self.warning then
		if self.confirm_duration > 0 then
			if self.confirm_duration >= DURATION then
				self.confirm_card._progress = nil
				vcard.mask(self.confirm_card, true)
			else
				vcard.mask(self.confirm_card, WARNING_MASK)
				local duration = self.confirm_duration / DURATION
				self.confirm_card._progress = duration
			end
		else
			self.confirm_card._progress = nil
		end
		if self.notice or self.focus ~= 0 then
			local f = self.focus
			f = f + 1
			if f >= DURATION * 2 then
				f = 0
			end
			self.focus = f
			if f >= DURATION then
				f = DURATION * 2 - 1 - f 
			end
			f = f + 1
			for c in pairs(self.cards) do
				vcard.mask(c, COLOR(f))
			end
		end
	end
end

function desktop.confirm(confirm_card, cards)
	local context = {
		cards = cards,
		confirm_card = confirm_card,
		warning = next(cards) ~= nil,
		confirm_duration = 0,
		focus = 0,
	}
	return setmetatable(context, confirm)
end

return desktop