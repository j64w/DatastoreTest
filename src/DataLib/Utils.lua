local Utils = {}

function Utils.Now()
    return os.time()
end

function Utils.DeepCopy(original, seen)
    if type(original) ~= "table" then return original end
    seen = seen or {}
    if seen[original] then return seen[original] end

    local copy = {}
    seen[original] = copy

    for k,v in pairs(original) do
        copy[Utils.DeepCopy(k, seen)] = Utils.DeepCopy(v, seen)
    end

    return copy
end

local function joinPath(path, key)
    if path == "" then return tostring(key) end
    return path .. "." .. tostring(key)
end

function Utils.CreateDeltaProxy(root, onChange, path, seen)
    if type(root) ~= "table" then return root end

    path = path or ""
    seen = seen or {}

    if seen[root] then return seen[root] end

    local proxy = {}
    seen[root] = proxy

    local mt = {}

    function mt.__index(_, key)
        local value = root[key]
        if type(value) == "table" then
            return Utils.CreateDeltaProxy(value, onChange, joinPath(path, key), seen)
        end
        return value
    end

    function mt.__newindex(_, key, value)
        root[key] = value
        onChange(joinPath(path, key), value)
    end

    function mt.__pairs()
        return function(_, k)
            local nk, nv = next(root, k)
            if type(nv) == "table" then
                nv = Utils.CreateDeltaProxy(nv, onChange, joinPath(path, nk), seen)
            end
            return nk, nv
        end, proxy, nil
    end

    setmetatable(proxy, mt)
    return proxy
end

return Utils