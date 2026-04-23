You are an expert Roblox Lua engineer.

Build a production-ready DataStore module for Roblox with the following goals:

# 🎯 GOAL

Create an ADVANCED but VERY EASY TO USE data system (simpler than ProfileService, but equally or more powerful internally).

The final API must be extremely simple:

```lua
local Data = require(DataLib)

local profile = Data:GetProfile(player)

profile.Data.coins += 100
profile.Data.level = 5
```

No complex setup required for the user.

---

# 🧱 ARCHITECTURE REQUIREMENTS

Implement the system in modular layers:

## 1. Public API Layer

* `DataLib:GetProfile(player)`
* Returns a session/profile object
* No DataStoreService exposed

---

## 2. Session Manager

Responsibilities:

* One active session per player
* Prevent duplicate loads across servers
* Use session locking with `game.JobId`
* Include timeout system for dead sessions
* Cache sessions in memory

### 🔴 SESSION LOCKING (CRITICAL)

You MUST define behavior when a lock already exists:

* If another server owns the lock and it is NOT expired:

  * Retry with exponential backoff
  * After max retries, optionally allow **forceLoad** (steal session)
* If the lock is expired:

  * Safely take over the session

Default behavior must be SAFE (no forceLoad), but allow configuration.

---

## 3. Memory Cache

* Store player data in memory
* Avoid unnecessary DataStore calls

---

## 4. Write System (REQUIRED)

Must include:

* Dirty flag system (only save if changed)
* Autosave loop (every 30–60 seconds)
* Write queue (batching system)

### 🔴 WRITE QUEUE RULES

* Do NOT write immediately on every change
* Do NOT spam UpdateAsync
* Queue dirty sessions and process them in batches
* Prevent duplicate queue entries per user

---

## 5. Retry Engine

* Use exponential backoff
* Retry failed DataStore operations safely

---

## 6. DataStore Adapter

Use ONLY `UpdateAsync`, never `SetAsync`

Responsibilities:

* Atomic updates
* Safe writes using transform functions
* ALWAYS deep copy before modifying data

---

## 7. Schema System

* Define a default schema
* Automatically fill missing fields on load (reconciliation)

Example:

```lua
local schema = {
    coins = 0,
    level = 1,
    inventory = {}
}
```

---

## 8. Data Integrity

* Validate data types
* Prevent corrupted saves
* Never overwrite with nil or invalid structures

---

# ⚙️ SESSION OBJECT REQUIREMENTS

Returned object must have:

```lua
profile.Data -- main data table

profile:Save() -- manual save (adds to queue)

profile:Release() -- called when player leaves
```

---

# 🔥 ADVANCED FEATURES (CRITICAL)

## 1. DIRTY TRACKING (RECURSIVE)

* Use metatables for automatic dirty tracking
* MUST support nested tables

### 🔴 REQUIRED BEHAVIOR

* Changes like this MUST mark dirty:

```lua
profile.Data.inventory.weapons.sword = true
```

* When assigning new tables:

```lua
profile.Data.inventory = {}
```

👉 The new table MUST automatically be wrapped with the dirty proxy

---

## 2. SESSION METADATA

Include:

* `_lock` (server JobId)
* `_lastSaveTime` (timestamp)

---

## 3. GRACEFUL SHUTDOWN

* Handle `game:BindToClose()`
* Save ALL dirty sessions before shutdown

---

## 4. PLAYER REMOVAL

* Handle `Players.PlayerRemoving`
* Save and release session

---

# 🧪 ERROR HANDLING

* Classify errors:

  * retryable
  * fatal
* Never crash the game
* Never lose valid data due to errors

---

# 📦 FILE STRUCTURE

Generate code split into modules:

* DataLib/init.lua
* SessionManager.lua
* RetryEngine.lua
* Schema.lua
* Utils.lua

---

# 🚫 CONSTRAINTS

* Do NOT overcomplicate the API
* Do NOT require the user to understand DataStores
* Do NOT use deprecated methods
* Do NOT spam DataStore requests

---

# 🎯 OUTPUT FORMAT

* Provide FULL WORKING CODE
* Each module separated clearly
* No pseudocode
* Clean, readable, documented

---

# 💡 PRIORITY

1. Simplicity for the user
2. Data safety
3. Performance
4. Scalability

Build this as if it will be used in a real Roblox game with thousands of players.
