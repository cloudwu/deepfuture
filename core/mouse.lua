local mouse = {}

local mouse_frame = 0
local mouse_x = 0
local mouse_y = 0
local mouse_press = {}	-- press from frame
local mouse_release = { false, false } -- is click
local mouse_state = {}	-- is press
local mouse_click = {}	-- for message
local mouse_click_get = {}
local focus = {
	frame = 0,
	object = nil,
	region = nil,
}

function mouse.mouse_move(x, y)
	mouse_x = x
	mouse_y = y
end


local BUTTON_ID = {
	left = 1,
	right = 2,
	mid = 3,
}
-- btn:0,1,2
-- state:true press
function mouse.mouse_button(btn, state)
	btn = BUTTON_ID[btn]
	if state then
		if not mouse_release[btn] then
			-- mouse_release[btn] == true means press again before mouse.frame()
			-- because mouse_release would reset after mouse.frame()
			mouse_press[btn] = mouse_frame
		end
		mouse_state[btn] = true
	else
		mouse_click[btn] = mouse_press[btn] or mouse_click[btn]	-- last click (press) time
		mouse_press[btn] = nil
		mouse_state[btn] = false
		mouse_release[btn] = true
	end
end

function mouse.set_focus(focus_region, focus_object)
	if focus.region ~= focus_region or focus.object ~= focus_object then
		focus.frame = mouse_frame
		focus.region = focus_region
		focus.object = focus_object
	end
	focus.set = true
end

function mouse.sync(frame)
	mouse_frame = frame
	return mouse_x, mouse_y
end

function mouse.frame()
	for i = 1, #mouse_release do
		if mouse_release[i] then
			-- is click
			mouse_release[i] = false
		end
	end
	if not focus.set then
		focus.region = false
		focus.object = false
	else
		focus.set = nil
	end
end

function mouse.get(focus_state)
	local change_region
	if focus.region ~= focus_state.active then
		change_region = true
		focus_state.lost = focus_state.active
		focus_state.active = focus.region
	end
	for i = 1, #mouse_release do
		focus_state[i] = mouse_click[i]
	end
	if change_region or focus_state.frame ~= focus.frame or focus.object ~= focus_state.object then
		focus_state.frame = focus.frame
		focus_state.object = focus.object
		return true
	end
end

function mouse.focus_time(focus_state)
	return mouse_frame - focus_state.frame or mouse_frame
end

function mouse.click(focus_state, btn)
	btn = BUTTON_ID[btn]
	local last_click = focus_state.click
	if not last_click then
		last_click = {}
		focus_state.click = last_click
	end
	if focus_state[btn] ~= last_click[btn] then
		local click_from = focus_state[btn]
		last_click[btn] = focus_state[btn]
		if click_from then
			if focus_state.object and click_from >= focus_state.frame then
				return focus_state.object, focus_state.active, mouse_frame - click_from
			end
		end
	end
end

function mouse.press(btn, object)
	if object ~= focus.region and object ~= focus.object then
		return
	end
	btn = BUTTON_ID[btn]
	if not mouse_state[btn] then
		return
	end
	local press_from = mouse_press[btn]
	if press_from then
		local focus_object = focus.object
		if focus_object then
			local focus_from = focus.frame
			local t = mouse_frame - (focus_from > press_from and focus_from or press_from)
			return t
		end
	end
end

function mouse.focus_region()
	return focus.region
end

return mouse
