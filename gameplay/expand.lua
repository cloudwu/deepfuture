local flow = require "core.flow"
local vdesktop = require "visual.desktop"
local card = require "gameplay.card"
local class = require "core.class"
local track = require "gameplay.track"
local map = require "gameplay.map"
local vmap = require "visual.map"
local vtips = require "visual.tips".layer "hud"
local mouse = require "core.mouse"
local vbutton = require "visual.button"
local loadsave = require "core.loadsave"
local sync = require "gameplay.sync"

global pairs, setmetatable, print, next, print_r

local adv_focus = {}

function adv_focus.communication()
	track.focus("M", true)
end
	
function adv_focus.astronomy()
	track.focus("X", true)
end

function adv_focus.religion()
	track.focus("C", true)
end

return function()
	loadsave.sync_game "expand"
	sync()
	vdesktop.set_text("phase", { text = "$(phase.action)" })
	local dist = 1
	local spacecraft = 0
	local start_region = map.expand_start(dist)
	local function mark_start(flag)
		for sec in pairs(start_region) do
			vmap.set_sector_mask(sec, flag)
		end
	end
	
	local expand_adv = {}

	function expand_adv.communication()
		track.advance("M", 1)
	end

	function expand_adv.astronomy()
		track.advance("X", 1)
	end

	function expand_adv.religion()
		track.advance("C", 2)
	end

	function expand_adv.spacecraft()
		spacecraft = spacecraft + 1
	end

	function expand_adv.ftl()
		dist = dist + 1
		if start_region then
			start_region = map.expand_start(dist)
			mark_start(true)
		else
			map.expand(dist)
		end
	end
	
	local map_message = {}
	local desc = {}

	function map_message.focus(sec)
		desc.sec = sec
		if start_region then
			-- choose start
			if start_region[sec] then
				vtips.set ("tips.expand.choose.valid", desc)
			else
				local n = map.player_ctrl(sec)
				if n then
					if n == 1 then
						desc.reason = "$(tips.expand.invalid.lost)"
					else
						desc.reason = "$(tips.expand.invalid.block)"
					end
				else
					desc.reason = "$(tips.expand.invalid.noctrl)"
				end
				vtips.set ("tips.expand.choose.invalid", desc)
			end
		else
			local ok, reason = map.check_expand(sec, spacecraft)
			if ok then
				-- can expand
				if map.expand_back(sec, true) then
					desc.undo = "$(tips.expand.undo)"
				else
					desc.undo = nil
				end
				vtips.set ("tips.expand.valid", desc)
			else
				if map.expand_back(sec, true) then
					desc.undo = "$(tips.expand.undo)"
				else
					desc.undo = nil
				end
				desc.reason = reason
				vtips.set ("tips.expand.invalid", desc)
			end
		end
	end
	
	function map_message.click(sec, button)
		if start_region then
			if button == "left" then
				if start_region[sec] then
					mark_start()
					map.expand_choose_start(sec)
					start_region = nil
					map.expand(dist)
					desc.from = sec
				end
			end
		elseif button == "left" then
			if map.check_expand(sec, spacecraft) then
				map.expand_people(sec, 1)
			end
		elseif button == "right" then
			map.expand_back(sec)
		end
		map_message.focus(sec)
	end

	vdesktop.set_text("phase", { extra = "[blue]$(EXPAND)[n]" })

	mark_start(true)

	local advs = class.effect "EXPAND"
	advs:add_pile "hand"
	advs:add_pile "homeworld"
	advs:add_pile "colony"

	local n = advs:update()
	if n > 0 then
		advs:choose_cards {
			n = n,
			phase = "expand",
			adv_focus = adv_focus,
			adv_func = expand_adv,
			map_message = map_message,
		}
		advs:discard_used_cards()
		advs:reset()
	end
	
	-- confirm
	local button = {
		text = "button.expand.confirm",
	}
	
	local function expand_check()
		local n, start = map.expand_count()
		button.n = n
		button.from = start
		if not n then
			button.disable = true
		else
			button.disable = nil
		end
		vbutton.update "button1"
	end

	vdesktop.button_enable("button1", button)
	expand_check()

	local focus_state = {}
	
	while true do
		if mouse.get(focus_state) then
			if focus_state.active == "map" then
				map_message.focus(focus_state.object)
			elseif focus_state.active == "button1" then
				if button.disable then
					vtips.set ("tips.expand.confirm.invalid", button)
				else
					vtips.set ("tips.expand.confirm", button)
				end
			else
				vtips.set()
			end
		end
		local c, btn = mouse.click(focus_state, "left")
		if c then
			if btn == "button1" then
				break
			elseif btn == "map" then
				map_message.click(c, "left")
				expand_check()
			end
		end
		local c, btn = mouse.click(focus_state, "right")
		if btn == "map" then
			map_message.click(c, "right")
			expand_check()
		end
		flow.sleep(0)
	end
	vdesktop.button_enable("button1", nil)
	
	map:reset()
	
	-- todo : wonder
	flow.sleep(1)
	
	return flow.state.action
end
