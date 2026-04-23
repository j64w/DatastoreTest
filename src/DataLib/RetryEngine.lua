local RetryEngine = {}

local CONFIG = {
    MaxRetries = 5,
    BaseDelay = 1
}

local function isRetryable(err)
    if typeof(err) ~= "string" then
        return false
    end

    err = string.lower(err)

    if string.find(err, "throttle") then return true end
    if string.find(err, "timeout") then return true end
    if string.find(err, "locked") then return true end
    if string.find(err, "queue") then return true end

    return false
end

function RetryEngine.Run(callback)
    local attempts = 0

    while attempts < CONFIG.MaxRetries do
        attempts += 1

        local success, result = pcall(callback)

        if success then
            return result
        end

        if not isRetryable(result) then
            return nil, result
        end

        task.wait(CONFIG.BaseDelay * (2 ^ (attempts - 1)))
    end

    return nil, "Max retries reached"
end

return RetryEngine