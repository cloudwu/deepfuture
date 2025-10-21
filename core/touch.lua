local mouse = require "core.mouse"

local TOUCH_LONG_PRESS_FRAMES <const> = 18
local TOUCH_MOVE_THRESHOLD2 <const> = 12 * 12
-- Regions that require a confirmation tap.
local DOUBLE_TAP_REGIONS <const> = {
	hand = true,
	neutral = true,
	homeworld = true,
	colony = true,
	discard = true,
	deck = true,
	card = true,
}

local REGION_CONFIRM_DOUBLE <const> = {
	deck = true,
}

local touch = {}

local current_frame = 0
local pending_clear_focus

local function dist2(x1, y1, x2, y2)
	local dx = x1 - x2
	local dy = y1 - y2
	return dx * dx + dy * dy
end

local state = {
	active = false,
	pressing = false,
	double_candidate = false,
	require_double = false,
	moved = false,
	start_frame = 0,
	start_x = 0,
	start_y = 0,
	x = 0,
	y = 0,
}

local last_tap = {
	require_double = false,
	object = nil,
	region = nil,
	x = 0,
	y = 0,
}

local function clear_last_tap()
	last_tap.require_double = false
	last_tap.object = nil
	last_tap.region = nil
	last_tap.x = 0
	last_tap.y = 0
end

local function store_last_tap(focus_object, region, x, y)
	if focus_object then
		last_tap.require_double = true
		last_tap.object = focus_object
		last_tap.region = region
		last_tap.x = x
		last_tap.y = y
		return true
	end
	if region and REGION_CONFIRM_DOUBLE[region] then
		last_tap.require_double = true
		last_tap.object = nil
		last_tap.region = region
		last_tap.x = x
		last_tap.y = y
		return true
	end
	clear_last_tap()
end

local function reset_state()
	state.active = false
	state.pressing = false
	state.double_candidate = false
	state.require_double = false
	state.moved = false
	state.start_frame = 0
	state.start_x = 0
	state.start_y = 0
	state.x = 0
	state.y = 0
end

local function apply_press()
	if state.pressing then
		return
	end
	mouse.mouse_button("left", true)
	state.pressing = true
	state.double_candidate = false
	clear_last_tap()
end

function touch.begin(x, y)
	mouse.mouse_move(x, y)
	state.active = true
	state.pressing = false
	state.moved = false
	state.start_frame = current_frame
	state.start_x = x
	state.start_y = y
	state.x = x
	state.y = y
	state.double_candidate = false
	state.require_double = false
	local region = mouse.focus_region()
	if region and DOUBLE_TAP_REGIONS[region] then
		state.require_double = true
	end
	if last_tap.require_double then
		local focus_object = mouse.focus_object()
		local same_object = focus_object and focus_object == last_tap.object
		local same_region = (focus_object == nil and last_tap.object == nil and region ~= nil and REGION_CONFIRM_DOUBLE[region] and region == last_tap.region)
		if same_object or same_region then
			state.double_candidate = true
		else
			clear_last_tap()
		end
	end
end

function touch.moved(x, y)
	mouse.mouse_move(x, y)
	state.x = x
	state.y = y
	if not state.active then
		return
	end
	if not state.moved and dist2(x, y, state.start_x, state.start_y) > TOUCH_MOVE_THRESHOLD2 then
		state.moved = true
		state.double_candidate = false
	end
end

function touch.ended(x, y)
	mouse.mouse_move(x, y)
	state.x = x
	state.y = y
	local region = mouse.focus_region()
	if state.pressing then
		mouse.mouse_button("left", false)
		clear_last_tap()
		reset_state()
		return
	end
	if state.active then
		if not state.moved then
			if state.require_double then
				if state.double_candidate then
					mouse.mouse_button("left", true)
					mouse.mouse_button("left", false)
					clear_last_tap()
					pending_clear_focus = true
				else
					local focus_object = mouse.focus_object()
					if not store_last_tap(focus_object, region, state.x, state.y) then
						reset_state()
						return
					end
				end
			else
				mouse.mouse_button("left", true)
				mouse.mouse_button("left", false)
				clear_last_tap()
			end
		else
			clear_last_tap()
		end
	end
	reset_state()
end

function touch.update(frame)
	current_frame = frame
	if pending_clear_focus then
		mouse.set_focus(nil, nil)
		pending_clear_focus = nil
	end
	if not state.active then
		return
	end
	local region = mouse.focus_region()
	local need_double = region and DOUBLE_TAP_REGIONS[region] or false
	state.require_double = need_double
	if need_double then
		local candidate = false
		if last_tap.require_double then
			local focus_object = mouse.focus_object()
			if focus_object and focus_object == last_tap.object then
				candidate = true
			elseif focus_object == nil and last_tap.object == nil and REGION_CONFIRM_DOUBLE[region] and region == last_tap.region then
				candidate = true
			end
		end
		state.double_candidate = candidate
	else
		state.double_candidate = false
	end
	if state.pressing or state.moved then
		return
	end
	if frame - state.start_frame >= TOUCH_LONG_PRESS_FRAMES then
		apply_press()
	end
end

return touch
