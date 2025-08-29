local util = {}

local next = next
global type, getmetatable, setmetatable, pairs

-- todo: flush all cache (change localization)
function util.cache(f)
	local meta
	if type(f) == "function" then
		meta = {}
		function meta:__index(k)
			local v = f(k)
			self[k] = v
			return v
		end
	else
		meta = getmetatable(f)
	end
	
	return setmetatable({}, meta)
end

function util.map(func)
	return function(list)
		local r = {}
		for i = 1, #list do
			local key = list[i]
			r[key] = func(key)
		end
		return r
	end
end

local dirty_flag = {}

function util.dirty_update(f)
	local function update(...)
		local last = dirty_flag[update]
		if last == nil then
			local r = f(...)
			if r == nil then
				r = true
			end
			dirty_flag[update] = r
			return r
		else
			return last
		end
	end
	return update
end

function util.dirty_trigger(update)
	dirty_flag[update] = nil
end

function util.shallow_clone(from, to)
	for k,v in pairs(from) do
		to[k] = v
	end
	return to
end

function util.keys(t)
	local keys = {}
	local n = 1
	for k in pairs(t) do
		keys[n] = k
		n = n + 1
	end
	return keys
end

return util