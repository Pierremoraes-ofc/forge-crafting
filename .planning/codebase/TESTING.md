# Testing Practices

**Analysis Date:** 2026-09-30

## Test Framework & Tooling

- **Automated Test Suites:** None currently configured (no Busted, LuaUnit, or CI test runners in the repository).
- **Primary Testing Strategy:** In-game functional testing on a FiveM development server.
- **Diagnostics & Debug Flags:**
  - `Config.Debug = false` in `shared/config.lua` enables debug visualizers for box zones and table hitboxes when enabled.
  - Console error logging and FiveM client F8 console / server console output.

## Manual Testing & Verification Scenarios

### 1. Resource Initialization & Schema
- **Scenario:** Start or restart the resource (`ensure forge-crafting`).
- **Checkpoints:**
  - Server console should report no SQL syntax errors.
  - Tables `forge-crafting` and `forge-crafting-items` exist in database.
  - New columns (`model`, `anim`, `level`) are verified or added if missing.
  - No nil framework errors from `bridge/framework.lua`.

### 2. Table Creation & Placement (Admin)
- **Scenario:** Run `/create` or `/craft:create` as an authorized admin.
- **Checkpoints:**
  - Raycast preview prop spawns and follows crosshair smoothly.
  - Arrow keys rotate the prop heading; Enter confirms; Backspace cancels.
  - Form dialog prompts for table name, jobs/gangs, and blip settings.
  - Table is inserted into `forge-crafting` table in database.
  - Physical prop and `ox_target` interaction point appear in world.

### 3. Permission & Access Control
- **Scenario:** Attempt `/create` or `/edit` without admin/crafting ACE permissions.
- **Checkpoints:**
  - Server denies request via `forge-crafting:PermisionCheck`.
  - Notification displayed: `insufficient_permission` / `Você não tem permissão para esse comando.`
  - No admin menus open.

### 4. Crafting Loop & Recipe Verification
- **Scenario:** Approach an existing crafting table and press target key.
- **Checkpoints:**
  - Crafting menu displays item catalog with correct icons, labels, and recipe requirements.
  - Items with unmet levels (`forge-reputation`) or missing items are clearly indicated or locked.
  - Initiating craft runs progress bar (`lib.progressCircle` or `lib.progressBar`).
  - Upon completion: required ingredients are removed, crafted item is added to inventory, and reputation XP is granted.
  - Cancelling progress interrupts craft without consuming items or granting rewards.

### 5. Table Management & Deletion
- **Scenario:** Run `/edit` or `/craft:edit`.
- **Checkpoints:**
  - Lists all existing tables.
  - Renaming updates DB and world blip/target without server restart.
  - Deleting table deletes DB row and removes world prop and `ox_target` registration immediately.

## Recommended Quality Enhancements

- Integrate static analysis via `luacheck` to catch undefined variables and globals.
- Add simulated test harness for bridge functions (`mock_ox_inventory`, `mock_qb_core`).

---

*Testing analysis: 2026-09-30*
*Update when testing approach changes*
