local util = {}

local next = next
global type, getmetatable, setmetatable, pairs, tostring, error

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

local function set_true()
	return true
end

local function set_index(_, index)
	return index
end

function util.map(func)
	if func == true then
		func = set_true
	elseif func == 0 then
		func = set_index
	end
	return function(list)
		local r = {}
		for i = 1, #list do
			local key = list[i]
			r[key] = func(key, i)
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
				r = false
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

local function merge(merge_into, patch)
	for k,v in pairs(patch) do
		local s = merge_into[k]
		if s == nil then
			merge_into[k] = v
		elseif type(s) ~= "table" or type(v) ~= "table" then
			-- error
			return tostring(k)
		else
			local errkey = merge(s, v)
			if errkey then
				return tostring(k) .. "." .. errkey
			end
		end
	end
end

function util.merge_table(merge_into, patch)
	local errkey = merge(merge_into, patch)
	if errkey then
		error("Invalid key " .. errkey)
	else
		return merge_into
	end
end

return util