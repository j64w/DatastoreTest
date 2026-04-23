-- Utils.lua
-- DirtyProxy, StripProxy, DeepCopy, helpers.

local Utils = {}

-- ─────────────────────────────────────────────
--  DeepCopy
-- ─────────────────────────────────────────────
function Utils.DeepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = Utils.DeepCopy(v)
	end
	return copy
end

-- ─────────────────────────────────────────────
--  MakeDirtyProxy(tbl, onDirty)
--
--  Wraps a table recursively. Any __newindex
--  fires onDirty() and re-wraps assigned tables.
-- ─────────────────────────────────────────────
function Utils.MakeDirtyProxy(tbl, onDirty)
	local raw = {}

	for k, v in pairs(tbl) do
		if type(v) == "table" then
			raw[k] = Utils.MakeDirtyProxy(v, onDirty)
		else
			raw[k] = v
		end
	end

	return setmetatable({}, {
		__index = function(_, k)
			return raw[k]
		end,

		__newindex = function(_, k, v)
			if type(v) == "table" then
				v = Utils.MakeDirtyProxy(v, onDirty)
			end
			raw[k] = v
			onDirty()
		end,

		__pairs = function(_)
			return next, raw, nil
		end,

		__ipairs = function(_)
			return ipairs(raw)
		end,

		__rawTable = function()
			return raw
		end,

		__type = "DirtyProxy",
	})
end

-- ─────────────────────────────────────────────
--  StripProxy(value)
--  Returns a plain deep copy with no metatables.
--  Safe to serialize to DataStore.
-- ─────────────────────────────────────────────
function Utils.StripProxy(value)
	if type(value) ~= "table" then return value end
	local mt  = getmetatable(value)
	local raw = (mt and mt.__rawTable) and mt.__rawTable() or value
	local copy = {}
	for k, v in pairs(raw) do
		copy[k] = Utils.StripProxy(v)
	end
	return copy
end

-- ─────────────────────────────────────────────
--  IsRetryableError(err)
-- ─────────────────────────────────────────────
function Utils.IsRetryableError(err)
	if type(err) ~= "string" then return false end
	local patterns = {
		"TooManyRequests",
		"Throttled",
		"ConnectFailed",
		"ServiceUnavailable",
		"InternalError",
		"Request was throttled",
		"DataStore service is not enabled",
	}
	for _, p in ipairs(patterns) do
		if err:find(p) then return true end
	end
	return false
end

-- ─────────────────────────────────────────────
--  Now() — unix timestamp
-- ─────────────────────────────────────────────
function Utils.Now()
	return math.floor(tick())
end

return Utils