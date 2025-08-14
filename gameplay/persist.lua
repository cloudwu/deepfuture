local datalist = require "soluna.datalist"
local file = require "soluna.file"
local version = require "gameplay.version"

local SUPPORT_VERSION <const> = "0.1.0"

local DATA = {}

local persist = {}

local function loadfile(filename)
	local data = datalist.parse(file.loader(filename))
	assert(data.version and version.older_than(data.version, SUPPORT_VERSION))
	DATA = data
end

function persist.init(entry, init)
	assert(DATA[entry] == nil)
	DATA[entry] = init
	return init
end

function persist.drop(entry)
	DATA[entry] = nil
end

function persist.load(filename)
	return pcall(loadfile, filename)	
end

do
	local function quote(s)
		if s:find "%A" then
			return datalist.quote(s)
		else
			return s
		end
	end
	local function sort_keys(t)
		local r = {}
		local n = 1
		for k in pairs(t) do
			if type(k) == "string" and k:byte() ~= 95 then	-- '_' == 95
				r[n] = k; n = n + 1
			end
		end
		table.sort(r)
		return r
	end
	
	local function tolist(v)
		local t = {}
		for i = 1, #v do
			local item = v[i]
			if type(item) == "string" then
				t[i] = quote(item)
			else
				t[i] = tostring(item)
			end
		end
		return "{ " .. table.concat(t, ",") .. " }"
	end

	local function write_kv(f, t, ident)
		local keys = sort_keys(t)
		for i = 1, #keys do	
			local k = keys[i]
			local v = t[k]
			local t = type(v)
			if t == "string" then
				v = quote(v)
			elseif t == "table" then
				v = tolist(v)
			else
				v = tostring(v)
			end
			f:write(ident, k, ":", v, "\n")
		end
	end

	local function write_object(f, key, object)
		f:write(key, ":\n")
		write_kv(f, object, "\t")
	end

	local function write_list(f, key, list)
		if #list == 0 then
			f:write(key, ":{}\n")
		else
			if type(list[1]) == "table" then
				f:write(key, ":\n")
				for _, item in ipairs(list) do
					f:write("\t---\n")
					write_kv(f, item, "\t")
				end
			else
				f:write(key, ":", tolist(list), "\n")
			end
		end
	end
	
	function persist.save(filename)
		local data = DATA
		local f <close> = io.open(filename, "wb")
		if not f then
			print ("Save to " .. filename .. " failed")
			return false
		end
		data.version = version.full()
		local keys = sort_keys(data)
		for _, key in ipairs(keys) do
			local v = data[key]
			local t = type(v)
			if t == "table" then
				if v._type == "list" then
					write_list(f, key, v)
				else
					write_object(f, key, v)
				end
			else
				f:write(key, ":", tostring(v), "\n")
			end
		end
		f:close()
		return true
	end
end


return persist
