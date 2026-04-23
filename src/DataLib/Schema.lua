local Schema = {}

local DEFAULT = {
    coins = 0,
    level = 1,
    inventory = {}
}

local function deepReconcile(data, template)
    for key, value in pairs(template) do
        if data[key] == nil then
            if type(value) == "table" then
                data[key] = {}
                deepReconcile(data[key], value)
            else
                data[key] = value
            end
        elseif type(value) == "table" and type(data[key]) == "table" then
            deepReconcile(data[key], value)
        end
    end
end

local function validateType(value, template)
    if type(template) ~= type(value) then
        return false
    end

    if type(value) == "table" then
        for k, v in pairs(value) do
            if template[k] ~= nil then
                if not validateType(v, template[k]) then
                    return false
                end
            end
        end
    end

    return true
end

function Schema.Reconcile(data)
    deepReconcile(data, DEFAULT)
end

function Schema.Validate(data)
    if type(data) ~= "table" then
        return false, "Data is not a table"
    end

    if not validateType(data, DEFAULT) then
        return false, "Invalid data structure"
    end

    return true
end

return Schema