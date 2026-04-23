-- DataLib_Tests.server.lua
-- Test suite v2 — cubre Promises, State machine, Signals, Trove, Schema con t.
-- Pegá en src/Server/ y correlo con Play en Studio.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Promise  = require(Packages.Promise)
local Signal   = require(Packages.Signal)
local Trove    = require(Packages.Trove)

local DataLib        = require(game.ServerScriptService.DataLib)
local Session        = require(game.ServerScriptService.DataLib.Session)
local Schema         = require(game.ServerScriptService.DataLib.Schema)
local Utils          = require(game.ServerScriptService.DataLib.Utils)
local RetryEngine    = require(game.ServerScriptService.DataLib.RetryEngine)

-- ─────────────────────────────────────────────
--  TEST RUNNER
-- ─────────────────────────────────────────────
local passed = 0
local failed = 0
local total  = 0

local function test(name, fn)
	total += 1
	-- fn puede devolver una Promise o ser sync
	local ok, result = pcall(fn)

	if not ok then
		warn(("  ❌ %s\n     %s"):format(name, tostring(result)))
		failed += 1
		return
	end

	-- Si devolvió una Promise, esperamos el resultado
	if Promise.is(result) then
		local status, value = result:await()
		if not status then
			warn(("  ❌ %s (Promise rejected)\n     %s"):format(name, tostring(value)))
			failed += 1
			return
		end
	end

	print(("  ✅ %s"):format(name))
	passed += 1
end

local function assert_eq(a, b, msg)
	if a ~= b then
		error((msg or "assert_eq") .. (" | expected: %s | got: %s"):format(tostring(b), tostring(a)), 2)
	end
end

local function assert_true(v, msg)
	if not v then error(msg or "expected true, got false", 2) end
end

local function assert_type(v, t, msg)
	if type(v) ~= t then
		error((msg or "wrong type") .. (" | expected %s got %s"):format(t, type(v)), 2)
	end
end

local function assert_state(session, expectedState)
	local s = session:GetState()
	if s ~= expectedState then
		error(("expected state %s, got %s"):format(expectedState, s), 2)
	end
end

-- ─────────────────────────────────────────────
--  MOCK PLAYER
-- ─────────────────────────────────────────────
local function makeMock(userId, name)
	userId = userId or math.random(1e6, 9e6)
	name   = name or ("Mock_" .. userId)
	return {
		UserId = userId,
		Name   = name,
		IsA    = function(_, c) return c == "Player" end,
	}
end

-- ─────────────────────────────────────────────
--  SUITE 1: SCHEMA + t
-- ─────────────────────────────────────────────
local function runSchemaTests()
	print("\n── Suite 1: Schema + t ──")

	test("Reconcile fills missing fields", function()
		local data = { coins = 50 }
		Schema.Reconcile(data)
		assert_type(data.level,     "number")
		assert_type(data.xp,        "number")
		assert_type(data.rebirths,  "number")
		assert_type(data.inventory, "table")
		assert_eq(data.coins, 50)
	end)

	test("Reconcile does not overwrite existing values", function()
		local data = { coins = 999, level = 42 }
		Schema.Reconcile(data)
		assert_eq(data.coins, 999)
		assert_eq(data.level, 42)
	end)

	test("Reconcile fills nested inventory fields", function()
		local data = { inventory = { pets = {} } }
		Schema.Reconcile(data)
		assert_type(data.inventory.equipment, "table")
	end)

	test("Validate accepts valid data (t)", function()
		local ok, err = Schema.Validate({
			_version  = 1,
			coins     = 100,
			level     = 5,
			xp        = 200,
			rebirths  = 0,
			inventory = {
				pets = {
					{ name = "Dragon", rarity = "Legendary", level = 10, equipped = true }
				},
				equipment = {},
			},
		})
		assert_true(ok, tostring(err))
	end)

	test("Validate rejects non-table", function()
		local ok, _ = Schema.Validate("corrupted")
		assert_true(not ok)
	end)

	test("Validate rejects negative coins (numberMin)", function()
		local ok, _ = Schema.Validate({
			_version = 1, coins = -1, level = 1, xp = 0, rebirths = 0,
			inventory = { pets = {}, equipment = {} },
		})
		assert_true(not ok, "negative coins should fail")
	end)

	test("Validate rejects invalid pet rarity (union/literal)", function()
		local ok, _ = Schema.Validate({
			_version = 1, coins = 0, level = 1, xp = 0, rebirths = 0,
			inventory = {
				pets = {
					{ name = "X", rarity = "Mythic", level = 1, equipped = false }
				},
				equipment = {},
			},
		})
		assert_true(not ok, "invalid rarity should fail")
	end)

	test("Validate rejects pet level out of range (numberConstrained)", function()
		local ok, _ = Schema.Validate({
			_version = 1, coins = 0, level = 1, xp = 0, rebirths = 0,
			inventory = {
				pets = {
					{ name = "X", rarity = "Common", level = 999, equipped = false }
				},
				equipment = {},
			},
		})
		assert_true(not ok, "pet level 999 should fail")
	end)

	test("Migrate v0 → v1 converts flat inventory", function()
		local data = { _version = 0, inventory = {} }
		Schema.Migrate(data)
		assert_eq(data._version, 1)
		assert_type(data.inventory.pets,      "table")
		assert_type(data.inventory.equipment, "table")
	end)

	test("Migrate is idempotent on current version", function()
		local data = {
			_version  = 1,
			inventory = { pets = { "already" }, equipment = {} }
		}
		Schema.Migrate(data)
		assert_eq(data.inventory.pets[1], "already")
	end)

	test("DeepCopy creates independent copy", function()
		local orig = { a = { b = 1 } }
		local copy = Schema.DeepCopy(orig)
		copy.a.b = 999
		assert_eq(orig.a.b, 1)
	end)
end

-- ─────────────────────────────────────────────
--  SUITE 2: UTILS
-- ─────────────────────────────────────────────
local function runUtilsTests()
	print("\n── Suite 2: Utils ──")

	test("DeepCopy is independent", function()
		local t = { x = { y = 42 } }
		local c = Utils.DeepCopy(t)
		c.x.y = 0
		assert_eq(t.x.y, 42)
	end)

	test("DirtyProxy marks dirty on set", function()
		local dirty = false
		local proxy = Utils.MakeDirtyProxy({ coins = 0 }, function() dirty = true end)
		proxy.coins = 100
		assert_true(dirty)
	end)

	test("DirtyProxy reads correctly", function()
		local proxy = Utils.MakeDirtyProxy({ level = 7 }, function() end)
		assert_eq(proxy.level, 7)
	end)

	test("DirtyProxy nested set marks dirty", function()
		local dirty = false
		local proxy = Utils.MakeDirtyProxy(
			{ inventory = { weapons = {} } },
			function() dirty = true end
		)
		dirty = false
		proxy.inventory.weapons.sword = true
		assert_true(dirty)
	end)

	test("DirtyProxy wraps newly assigned tables", function()
		local dirty = false
		local proxy = Utils.MakeDirtyProxy({}, function() dirty = true end)
		proxy.inventory = {}
		dirty = false
		proxy.inventory.shield = true
		assert_true(dirty, "new table must also be wrapped")
	end)

	test("StripProxy returns plain table", function()
		local proxy = Utils.MakeDirtyProxy(
			{ coins = 5, nested = { x = 1 } },
			function() end
		)
		local plain = Utils.StripProxy(proxy)
		assert_type(plain, "table")
		assert_eq(plain.coins, 5)
		assert_eq(plain.nested.x, 1)
		assert_true(getmetatable(plain) == nil, "no metatable on stripped table")
	end)

	test("IsRetryableError detects throttle patterns", function()
		assert_true(Utils.IsRetryableError("Request was throttled"))
		assert_true(Utils.IsRetryableError("TooManyRequests"))
		assert_true(Utils.IsRetryableError("ConnectFailed"))
	end)

	test("IsRetryableError returns false for fatal errors", function()
		assert_true(not Utils.IsRetryableError("Cannot store value of type userdata"))
		assert_true(not Utils.IsRetryableError("unknown error"))
	end)

	test("Now returns a number", function()
		assert_type(Utils.Now(), "number")
	end)
end

-- ─────────────────────────────────────────────
--  SUITE 3: RETRY ENGINE (Promises)
-- ─────────────────────────────────────────────
local function runRetryTests()
	print("\n── Suite 3: RetryEngine + Promise ──")

	test("Retry resolves on first try", function()
		return RetryEngine.Retry(function()
			return 42
		end, "Test:OK"):andThen(function(result)
			assert_eq(result, 42)
		end)
	end)

	test("Retry resolves after retryable failures", function()
		local attempts = 0
		return RetryEngine.Retry(function()
			attempts += 1
			if attempts < 3 then error("TooManyRequests") end
			return "ok"
		end, "Test:Retry"):andThen(function(result)
			assert_eq(result, "ok")
			assert_eq(attempts, 3)
		end)
	end)

	test("Retry rejects immediately on fatal error", function()
		local attempts = 0
		return RetryEngine.Retry(function()
			attempts += 1
			error("Cannot store userdata")
		end, "Test:Fatal")
		:andThen(function()
			error("Should have rejected")
		end)
		:catch(function()
			assert_eq(attempts, 1, "fatal error must not retry")
		end)
	end)

	test("Retry rejects after exhausting attempts", function()
		local attempts = 0
		return RetryEngine.Retry(function()
			attempts += 1
			error("TooManyRequests")
		end, "Test:Exhaust")
		:andThen(function()
			error("Should have rejected")
		end)
		:catch(function()
			assert_true(attempts > 1, "should have retried")
		end)
	end)

	test("Retry returns a Promise", function()
		local p = RetryEngine.Retry(function() return 1 end, "Test:IsPromise")
		assert_true(Promise.is(p), "must return a Promise")
		return p
	end)
end

-- ─────────────────────────────────────────────
--  SUITE 4: SESSION STATE MACHINE
-- ─────────────────────────────────────────────
local function runSessionTests()
	print("\n── Suite 4: Session State Machine ──")

	local function makeSession(data)
		local mock = makeMock()
		local s = Session.new(mock, data or { coins = 0, level = 1, xp = 0, rebirths = 0, inventory = { pets = {}, equipment = {} }, _version = 1 })
		return s
	end

	test("Session starts in ACTIVE state", function()
		local s = makeSession()
		assert_state(s, "ACTIVE")
	end)

	test("IsActive returns true when ACTIVE", function()
		local s = makeSession()
		assert_true(s:IsActive())
	end)

	test("Mutating Data marks _dirty", function()
		local s = makeSession()
		s._dirty = false
		s.Data.coins = 999
		assert_true(s._dirty)
	end)

	test("Mutation in RELEASED state does NOT mark dirty", function()
		local s = makeSession()
		s._state = Session.States.RELEASED
		s._dirty = false
		s.Data.coins = 999
		assert_true(not s._dirty, "released session should not go dirty")
	end)

	test("Save() rejects when RELEASED", function()
		local s = makeSession()
		s._state = Session.States.RELEASED
		return s:Save()
			:andThen(function() error("should have rejected") end)
			:catch(function(err)
				assert_true(err:find("released") or err:find("Released"), tostring(err))
			end)
	end)

	test("Save() rejects when ERROR", function()
		local s = makeSession()
		s:MarkError()
		return s:Save()
			:andThen(function() error("should have rejected") end)
			:catch(function(err)
				assert_true(err:find("error") or err:find("Error"), tostring(err))
			end)
	end)

	test("MarkError transitions to ERROR state", function()
		local s = makeSession()
		s:MarkError()
		assert_state(s, "ERROR")
	end)

	test("Release() transitions to RELEASED", function()
		local s = makeSession()
		-- Inject a no-op releaseFn
		s._releaseFn = function() return Promise.resolve() end
		return s:Release():andThen(function()
			assert_state(s, "RELEASED")
		end)
	end)

	test("Release() is idempotent (double release)", function()
		local s = makeSession()
		s._releaseFn = function() return Promise.resolve() end
		return s:Release():andThen(function()
			return s:Release()  -- second release must not error
		end)
	end)

	test("Trove is destroyed on Release", function()
		local s    = makeSession()
		local cleaned = false
		s:AddToTrove({ Destroy = function() cleaned = true end })
		s._releaseFn = function() return Promise.resolve() end
		return s:Release():andThen(function()
			assert_true(cleaned, "Trove must clean up on release")
		end)
	end)

	test("AddToTrove accepts connections", function()
		local s = makeSession()
		local sig = Signal.new()
		local conn = sig:Connect(function() end)
		s:AddToTrove(conn)
		-- Just verify it doesn't error — Trove will clean it on Release
	end)
end

-- ─────────────────────────────────────────────
--  SUITE 5: SIGNALS (DataLib public API)
-- ─────────────────────────────────────────────
local function runSignalTests()
	print("\n── Suite 5: Signals ──")

	test("DataLib.ProfileLoaded is a Signal", function()
		assert_true(DataLib.ProfileLoaded ~= nil)
		assert_type(DataLib.ProfileLoaded.Connect, "function")
	end)

	test("DataLib.ProfileReleased is a Signal", function()
		assert_true(DataLib.ProfileReleased ~= nil)
		assert_type(DataLib.ProfileReleased.Connect, "function")
	end)

	test("DataLib.SaveFailed is a Signal", function()
		assert_true(DataLib.SaveFailed ~= nil)
		assert_type(DataLib.SaveFailed.Connect, "function")
	end)

	test("ProfileLoaded fires and passes player + profile", function()
		return Promise.new(function(resolve, reject)
			local player = Players:GetPlayers()[1]
			if not player then
				-- No hay jugador, skip gracefully
				return resolve()
			end

			local conn
			conn = DataLib.ProfileLoaded:Connect(function(p, profile)
				conn:Disconnect()
				local ok = pcall(function()
					assert_true(p ~= nil, "player arg must not be nil")
					assert_true(profile ~= nil, "profile arg must not be nil")
					assert_true(profile.Data ~= nil, "profile.Data must exist")
				end)
				if ok then resolve() else reject("Signal args wrong") end
			end)

			-- Trigger by loading (may resolve from cache)
			DataLib:LoadProfile(player):catch(reject)
		end)
	end)
end

-- ─────────────────────────────────────────────
--  SUITE 6: PROFILE (real player, async)
-- ─────────────────────────────────────────────
local function runProfileTests(player)
	print("\n── Suite 6: Profile (jugador real) ──")

	test("LoadProfile returns a Promise", function()
		local p = DataLib:LoadProfile(player)
		assert_true(Promise.is(p), "must return a Promise")
		return p
	end)

	test("LoadProfile resolves with a profile", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			assert_true(profile ~= nil)
		end)
	end)

	test("profile.Data has all schema fields", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			assert_type(profile.Data.coins,    "number")
			assert_type(profile.Data.level,    "number")
			assert_type(profile.Data.xp,       "number")
			assert_type(profile.Data.rebirths, "number")
			assert_type(profile.Data.inventory, "table")
		end)
	end)

	test("Mutating Data marks dirty", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			profile._dirty = false
			profile.Data.coins += 1
			assert_true(profile._dirty)
		end)
	end)

	test("Deep mutation marks dirty", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			profile._dirty = false
			profile.Data.inventory.testKey = true
			assert_true(profile._dirty)
		end)
	end)

	test("Assigning new table and mutating marks dirty", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			profile.Data.inventory = { pets = {}, equipment = {} }
			profile._dirty = false
			profile.Data.inventory.newKey = 123
			assert_true(profile._dirty, "re-wrapped table must mark dirty")
		end)
	end)

	test("profile:Save() returns a Promise", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			local p = profile:Save()
			assert_true(Promise.is(p))
			return p
		end)
	end)

	test("GetProfile (sync) returns cached session", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			local cached = DataLib:GetProfile(player)
			assert_true(cached == profile, "must return same instance")
		end)
	end)

	test("LoadProfile called twice returns same session", function()
		return DataLib:LoadProfile(player):andThen(function(p1)
			return DataLib:LoadProfile(player):andThen(function(p2)
				assert_true(p1 == p2, "must be same session object")
			end)
		end)
	end)

	test("Session is in ACTIVE state after load", function()
		return DataLib:LoadProfile(player):andThen(function(profile)
			assert_state(profile, "ACTIVE")
		end)
	end)
end

-- ─────────────────────────────────────────────
--  SUITE 7: PERSISTENCIA (instrucciones manuales)
-- ─────────────────────────────────────────────
local function runPersistenceInstructions()
	print("\n── Suite 7: Persistencia (manual) ──")
	print([[
  RUN 1 — guardar datos:
    local profile = DataLib:GetProfile(player)
    profile.Data.coins = 77777
    profile:Save():andThen(function()
        print("✅ Guardado:", profile.Data.coins)
    end)

  Cerrá el servidor. Volvé a correr:

  RUN 2 — verificar persistencia:
    DataLib:LoadProfile(player):andThen(function(profile)
        print("Coins cargados:", profile.Data.coins)
        -- ✅ debe imprimir 77777
    end)

  RUN 3 — graceful shutdown (BindToClose):
    local profile = DataLib:GetProfile(player)
    profile.Data.coins = 99999
    -- NO llames Save()
    -- Apretá Stop en Studio
    -- Al reiniciar debe tener 99999
]])
end

-- ─────────────────────────────────────────────
--  SUMMARY
-- ─────────────────────────────────────────────
local function printSummary()
	print("\n──────────────────────────────")
	print(("  Total:  %d"):format(total))
	print(("  ✅ Passed: %d"):format(passed))
	if failed > 0 then
		warn(("  ❌ Failed: %d  ← revisar output"):format(failed))
	else
		print("  🎉 All tests passed!")
	end
	print("──────────────────────────────\n")
end

-- ─────────────────────────────────────────────
--  MAIN
-- ─────────────────────────────────────────────
print("\n╔══════════════════════════════════╗")
print("║   DataLib v2 — Test Suite        ║")
print("╚══════════════════════════════════╝")

-- Suites sincrónicas / Promise-based que no necesitan jugador real
runSchemaTests()
runUtilsTests()

-- RetryEngine tarda por los delays — correlo async
task.spawn(function()
	runRetryTests()

	runSessionTests()
	runSignalTests()

	-- Suites con jugador real
	local player = Players:GetPlayers()[1]
	if player then
		runProfileTests(player)
	else
		print("\n── Suite 6: Profile ──")
		print("  ⚠️  Entrá al juego (Play) para correr los tests de perfil.")
		Players.PlayerAdded:Connect(function(p)
			task.wait(2)
			runProfileTests(p)
			runPersistenceInstructions()
			printSummary()
		end)
	end

	runPersistenceInstructions()
	printSummary()
end)