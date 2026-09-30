# Integrations

**Analysis Date:** 2026-09-30

## External & Resource Integrations

### Database (MySQL / MariaDB via `oxmysql`)

- **Connection Driver:** `@oxmysql/lib/MySQL.lua`
- **Tables Managed:**
  - `forge-crafting`: Stores crafting table definitions (`craft_id`, `craft_name`, `crafting` JSON metadata, `blipdata` JSON, `jobs` JSON).
  - `forge-crafting-items`: Stores craftable items and their recipes (`craft_id`, `item`, `item_label`, `recipe` JSON, `time`, `amount`, `model`, `anim`, `level`).
- **Initialization:** Auto-migration / table creation on resource start in `bridge/server/insert.lua`.
- **Query Execution:** Uses both asynchronous (`MySQL.Async.execute`, `MySQL.query`) and synchronous execution (`MySQL.Sync.fetchAll`, `MySQL.Sync.execute` during startup schema checks).

### Roleplay Frameworks

- **QBCore / QBX (`qb-core`, `qbx_core`):**
  - Integrated via `bridge/framework.lua` (`exports['qb-core']:GetCoreObject()`) and `bridge/server/server.lua`.
  - Used for player identification (`QBCore.Functions.GetPlayer`), permissions, inventory fallback, callbacks, jobs (`exports.qbx_core:GetJobs()`), and gangs (`exports.qbx_core:GetGangs()`).
- **ESX Legacy (`es_extended`):**
  - Integrated via `bridge/framework.lua` (`exports["es_extended"]:getSharedObject()`).
  - Used for player retrieval (`ESX.GetPlayerFromId`), callbacks (`ESX.RegisterServerCallback`), inventory manipulation (`xPlayer.addInventoryItem`), jobs, and groups.

### Inventory System

- **ox_inventory:**
  - Invoked directly in `bridge/server/server.lua` (`exports.ox_inventory:GetItemCount(src, item)`) for recipe item availability verification.
  - Image assets resolved via `Config.ImagePath` (pointing to `nui://ox_inventory/web/images/`).
- **Framework Inventory Fallback:**
  - Fallback logic exists for `xPlayer.getInventoryItem` (ESX) and `xPlayer.Functions.GetItemByName` (QBCore) in `QT.GetItem`.

### Targeting System (`ox_target` / `qb-target`)

- **ox_target:**
  - Registered in `bridge/client/common.lua` via `exports.ox_target:addLocalEntity` and `exports.ox_target:addModel`.
  - Enables interaction zones on spawned crafting props with job, gang, and busy checks.
- **qb-target:**
  - Configurable in `shared/config.lua` (`Config.Target = "qb-target"`), with entity interaction hooks.

### Reputation & Progression (`forge-reputation`)

- **Skill Progression Export:**
  - Integrated in `sv_utils.lua` (`exports['forge-reputation']:updateSkill(source, Config.CraftingSkill, Config.CraftingSkillReward)`).
  - Queried in `bridge/client/common.lua` (`exports['forge-reputation']:getCurrentLevel(Config.CraftingSkill)`) to gate craftable recipes by character level / mastery.

### UI Library (`ox_lib`)

- Used extensively across `cl_utils.lua` and `bridge/client/common.lua`:
  - `lib.notify` for alerts.
  - `lib.registerContext` / `lib.showContext` for menu hierarchies (table editing, craft lists, item configuration).
  - `lib.inputDialog` and `lib.alertDialog` for administrative input and confirmations.
  - `lib.progressBar` and `lib.progressCircle` for crafting action timers.
  - `lib.require` for module importing (`raycast.lua`).

## Authentication & Authorization

- **ACE Permissions:**
  - Server-side callback `forge-crafting:PermisionCheck` checks `IsPlayerAceAllowed(source, 'admin')` or `IsPlayerAceAllowed(source, 'crafting')`.
- **Framework Group / Role Checks:**
  - ESX group checks (`xPlayer.getGroup()`) and QBCore permission checks (`QBCore.Functions.GetPermission`).
- **Job / Gang Restrictions:**
  - Configurable per crafting table; tables can be restricted to specific jobs (`QT.getjob()`) or gangs (`QT.getgang()`).

---

*Integrations analysis: 2026-09-30*
*Update after integration changes*
