# Codebase Concerns & Technical Debt

**Analysis Date:** 2026-09-30

## Critical Security Vulnerabilities

### 1. Unvalidated Client Item Spawning (`forge-crafting:ItemInterval`)
- **Location:** `sv_utils.lua#L13-L22`
- **Issue:** The net event `forge-crafting:ItemInterval` accepts `(task, item, count)` directly from the client. When `task == "add"`, it invokes `QT.AddItem(source, item, count)` without validating:
  1. Whether the player is currently near an authorized crafting table.
  2. Whether the player actually consumed the required recipe items.
  3. Whether the requested item and count match a legitimate crafting recipe.
- **Risk:** High/Critical. Any player with an executor or modified client can trigger this event to give themselves arbitrary items, weapons, or currency in any quantity.
- **Remediation:** Move crafting validation entirely to the server side (verify proximity, verify ingredients, deduct items on server, track crafting timers on server or via server callbacks, and award the item upon server-verified completion).

## Technical Debt & Fragile Areas

### 2. Manual Random ID vs Database Auto-Increment
- **Location:** `sv_utils.lua#L52`, `bridge/server/insert.lua#L5`
- **Issue:** The `forge-crafting` table defines `craft_id int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY`, but `sv_utils.lua` generates IDs manually using `math.random(1, 1000000)`.
- **Risk:** Primary key collision risk if the random number matches an existing ID, resulting in query failures during table creation.
- **Remediation:** Omit `craft_id` from the `INSERT` query and allow MySQL `AUTO_INCREMENT` to generate sequential unique IDs, retrieving `affectedRows.insertId`.

### 3. Inventory Bridge Coupling (`ox_inventory`)
- **Location:** `bridge/server/server.lua#L121-L137`
- **Issue:** `QT.HasItem` hardcodes `exports.ox_inventory:GetItemCount(src, item)`, ignoring `Config.Framework` fallback and commenting out native QBCore / ESX inventory checks.
- **Risk:** Crashes or fails on servers running `qb-inventory`, `qs-inventory`, or `ps-inventory`.
- **Remediation:** Implement framework-specific inventory checks within `QT.HasItem` matching the active inventory or framework configuration.

### 4. Locale Key Typo Mismatch
- **Location:** `shared/locales.lua#L5` vs `sv_utils.lua#L29`
- **Issue:** `shared/locales.lua` defines `insuficient_permission` (single 'f'), but `sv_utils.lua` attempts to read `locales.insufficient_permission` (double 'f').
- **Risk:** Accessing this key yields `nil`, resulting in blank notification messages when permission checks fail.
- **Remediation:** Standardize the key spelling across both files.

### 5. Hardcoded Job / Gang Name Filters
- **Location:** `sv_utils.lua#L37`, `sv_utils.lua#L44`
- **Issue:** The callback `forge-crafting:fetchJobs` filters out jobs and gangs by hardcoded strings: `v.label ~= 'Civil'` and `v.label ~= 'Sem gangue'`.
- **Risk:** Breaks compatibility on servers where default job or gang labels differ (e.g. English servers using 'unemployed' or 'none').
- **Remediation:** Move ignored jobs/gangs to `Config.IgnoredJobs = { ['unemployed'] = true, ['none'] = true }` checking job keys rather than translated labels.

### 6. Synchronous Database Operations at Server Startup
- **Location:** `bridge/server/insert.lua#L3-L49`
- **Issue:** Multiple `MySQL.Sync.execute` and `MySQL.Sync.fetchAll` queries are called synchronously on `onServerResourceStart`.
- **Risk:** Can block the main server thread during server initialization or resource restart.
- **Remediation:** Migrate to asynchronous queries (`MySQL.query`, `MySQL.Async.execute`) or standard migration files.

### 7. Large Data Dumps in Shared Folder
- **Location:** `shared/receita_nova.lua` (219 KB) and `shared/receita_tuning.lua` (43 KB)
- **Issue:** Massive tables loaded on both client and server via `shared_scripts` in `fxmanifest.lua`, consuming unnecessary client memory if they are only reference datasets.
- **Remediation:** If these are only reference imports for SQL, keep them out of `shared_scripts` or load them on-demand on the server side only.

---

*Concerns analysis: 2026-09-30*
*Update as issues are resolved or discovered*
