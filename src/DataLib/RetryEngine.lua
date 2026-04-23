-- RetryEngine.lua
-- Exponential backoff retry wrapper.
-- Returns a Promise that resolves with the result or rejects with the last error.

local Packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local Promise  = require(Packages.Promise)
local Utils    = require(script.Parent.Utils)

local RetryEngine = {}

local MAX_ATTEMPTS = 5
local BASE_DELAY   = 1
local MAX_DELAY    = 30
local JITTER_MAX   = 0.5

-- ─────────────────────────────────────────────
--  Retry(fn, label) → Promise
--
--  fn    — zero-arg function wrapping the DS call
--  label — string for logging
-- ─────────────────────────────────────────────
function RetryEngine.Retry(fn, label)
	label = label or "DataStore"

	return Promise.new(function(resolve, reject)
		local lastError

		for attempt = 1, MAX_ATTEMPTS do
			local ok, result = pcall(fn)

			if ok then
				return resolve(result)
			end

			lastError = result
			local isRetryable = Utils.IsRetryableError(tostring(result))

			warn(("[DataLib] %s — attempt %d/%d failed: %s"):format(
				label, attempt, MAX_ATTEMPTS, tostring(result)
			))

			if not isRetryable then
				warn(("[DataLib] %s — fatal error, aborting."):format(label))
				return reject(result)
			end

			if attempt < MAX_ATTEMPTS then
				local delay = math.min(BASE_DELAY * (2 ^ (attempt - 1)), MAX_DELAY)
				delay = delay + math.random() * JITTER_MAX
				Promise.delay(delay):await()
			end
		end

		warn(("[DataLib] %s — all %d attempts exhausted."):format(label, MAX_ATTEMPTS))
		reject(lastError)
	end)
end

return RetryEngine