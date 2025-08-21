local focus = {}

local FOCUS_ACTIVE
local FOCUS_LOST
local FOCUS_OBJECT

function focus.trigger(region, object)
	if object then
		if FOCUS_ACTIVE ~= region then
			FOCUS_LOST = FOCUS_ACTIVE
			FOCUS_ACTIVE = region
		end
		FOCUS_OBJECT = object
	elseif FOCUS_ACTIVE == region then
		FOCUS_ACTIVE = nil
		FOCUS_LOST = region
		FOCUS_OBJECT = nil
	end
end

function focus.region()
	return FOCUS_ACTIVE
end

function focus.dispatch(f)
	if FOCUS_LOST then
		local lost = f[FOCUS_LOST]
		if lost then
			lost(FOCUS_LOST)
		end
	end
	if FOCUS_ACTIVE then
		local active = f[FOCUS_ACTIVE]
		if active then
			active(FOCUS_ACTIVE, FOCUS_OBJECT)
		end
	end
end

return focus
