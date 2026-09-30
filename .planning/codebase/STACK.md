# Technology Stack

**Analysis Date:** 2026-09-30

## Languages

**Primary:**
- Lua 5.4 (`lua54 'yes'` in `fxmanifest.lua`) - Used for all client-side, server-side, and shared game logic.

**Secondary:**
- SQL (MySQL / MariaDB syntax) - Used in `bridge/server/insert.lua` and data dumps `shared/receita_nova.sql` for table schemas and migrations.

## Runtime

**Environment:**
- CitizenFX / FiveM FXServer (`cerulean` fx_version, `gta5` game target)
- In-engine Lua 5.4 runtime provided by FiveM

**Package / Resource Management:**
- FiveM Resource Manifest (`fxmanifest.lua`)
- Resource dependencies declared via `dependencies` block

## Frameworks & Core Libraries

**Core Framework Bridge:**
- Hybrid Bridge supporting **QBCore** (`qb-core` / `qbx_core`) and **ESX** (`es_extended`), configured in `shared/config.lua` (`Config.Framework = "qb"`).

**UI & Interaction Libraries:**
- `ox_lib` (`@ox_lib/init.lua`) - Context menus (`lib.registerContext`, `lib.showContext`), input dialogs (`lib.inputDialog`), alert dialogs (`lib.alertDialog`), notifications (`lib.notify`), and progress bars/circles (`lib.progressBar`, `lib.progressCircle`).
- `ox_target` / `qb-target` - Target interaction layer for crafting tables/props in the 3D world (`Config.Target = "ox_target"`).

**Database Connector:**
- `oxmysql` (`@oxmysql/lib/MySQL.lua`) - Asynchronous and synchronous MySQL query execution (`MySQL.Async.execute`, `MySQL.Sync.fetchAll`, `MySQL.query`).

## Key Dependencies

**Critical:**
- `ox_lib` - Essential UI, caching, math helpers, and progress widgets across `cl_utils.lua` and `bridge/client/common.lua`.
- `oxmysql` - Database persistence for crafting benches (`forge-crafting`) and item recipes (`forge-crafting-items`).
- `ox_inventory` (or compatible inventory) - Server-side inventory checks (`exports.ox_inventory:GetItemCount`) in `bridge/server/server.lua` and client item icons via `Config.ImagePath`.
- `forge-reputation` - Level / skill progression system integration (`exports['forge-reputation']:updateSkill` and `getCurrentLevel`).

**Infrastructure:**
- CitizenFX native API - GTA V engine natives (`CreateObject`, `PlaceObjectOnGroundProperly`, `SetEntityHeading`, raycasting, entity deletion).

## Configuration

**Environment & Resource Config:**
- `shared/config.lua` - Framework selection (`Config.Framework`), targeting system (`Config.Target`), progress system (`Config.OxProgress`), image paths (`Config.ImagePath`), commands (`Config.CreateTableCommand`, `Config.EditMenuCommand`), permissions, and debug flags.
- `shared/locales.lua` - Multilingual locale dictionary (Portuguese default) containing all UI strings, descriptions, prompts, and system notifications.

**Manifest:**
- `fxmanifest.lua` - Manifest declaring script load orders, dependencies, and Lua 5.4 flag.

## Platform Requirements

**Development:**
- FiveM development server or local FXServer environment.
- MySQL / MariaDB database with oxmysql configured.

**Production:**
- FiveM server running artifacts with Lua 5.4 support.
- MariaDB / MySQL 8.0+.
- Active dependencies: `ox_lib`, `oxmysql`, and configured inventory / framework (`qb-core` or `qbx_core` / `es_extended`).

---

*Stack analysis: 2026-09-30*
*Update after major dependency changes*
