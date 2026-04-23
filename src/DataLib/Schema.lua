-- Schema.lua
-- Define el schema por defecto, validación con `t`, y migraciones.

local Packages = game:GetService("ReplicatedStorage"):WaitForChild("Packages")
local t        = require(Packages.T)

local Schema = {}

-- ─────────────────────────────────────────────
--  DEFAULT SCHEMA
--  Editá esto para agregar campos al juego.
-- ─────────────────────────────────────────────
Schema.Default = {
	_version  = 1,
	coins     = 0,
	level     = 1,
	xp        = 0,
	rebirths  = 0,
	inventory = {
		pets      = {},
		equipment = {},
	},
}

-- ─────────────────────────────────────────────
--  VALIDATORS
-- ─────────────────────────────────────────────
local petValidator = t.interface({
	name     = t.string,
	rarity   = t.union(
		t.literal("Common"),
		t.literal("Uncommon"),
		t.literal("Rare"),
		t.literal("Legendary")
	),
	level    = t.numberConstrained(1, 100),
	equipped = t.boolean,
})

local inventoryValidator = t.interface({
	pets      = t.array(petValidator),
	equipment = t.table,
})

local profileValidator = t.strictInterface({
	_version  = t.number,
	coins     = t.numberMin(0),
	level     = t.numberMin(1),
	xp        = t.numberMin(0),
	rebirths  = t.numberMin(0),
	inventory = inventoryValidator,
})

function Schema.Validate(data)
	return profileValidator(data)
end

-- ─────────────────────────────────────────────
--  RECONCILE
--  Fills missing fields recursively without
--  overwriting existing values.
-- ─────────────────────────────────────────────
function Schema.Reconcile(data, template)
	template = template or Schema.Default
	for key, defaultValue in pairs(template) do
		if data[key] == nil then
			if type(defaultValue) == "table" then
				data[key] = Schema.DeepCopy(defaultValue)
			else
				data[key] = defaultValue
			end
		elseif type(defaultValue) == "table" and type(data[key]) == "table" then
			Schema.Reconcile(data[key], defaultValue)
		end
	end
	return data
end

-- ─────────────────────────────────────────────
--  MIGRATE
--  Bump Schema.Default._version when you make
--  breaking changes and add a block below.
-- ─────────────────────────────────────────────
function Schema.Migrate(data)
	local version = data._version or 0

	-- v0 → v1: flat inventory → { pets, equipment }
	if version < 1 then
		if type(data.inventory) ~= "table" then
			data.inventory = {}
		end
		data.inventory.pets      = data.inventory.pets      or {}
		data.inventory.equipment = data.inventory.equipment or {}
		data._version = 1
	end

	-- Add future migrations here:
	-- if version < 2 then ... data._version = 2 end

	return data
end

-- ─────────────────────────────────────────────
--  DEEP COPY
-- ─────────────────────────────────────────────
function Schema.DeepCopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = Schema.DeepCopy(v)
	end
	return copy
end

return Schema