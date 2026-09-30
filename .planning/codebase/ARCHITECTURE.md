# Architecture

**Analysis Date:** 2026-09-30

## Pattern Overview

**Overall:** Client-Server FiveM Resource with Modular Framework Bridge

**Key Characteristics:**
- **Bridge Pattern (`QT` abstraction layer):** Decouples gameplay logic from underlying framework APIs (`ESX` vs `QBCore`), standardizing callbacks, player identification, inventory manipulation, and notification dispatches.
- **Event-Driven & Callback Flow:** Employs asynchronous server callbacks (`QT.TriggerCallback` / `QT.RegisterCallback`) for data synchronization and client-to-server validation.
- **Data Persistence in Relational DB:** Table definitions and recipe manifests persist in MySQL via `oxmysql` with dynamic schema patching at startup.
- **Context-Based UI Hierarchy:** Fully builds UI menus on the client through `ox_lib` context menus and input modals.

## Layers

### 1. Configuration & Shared Definitions (`shared/`)
- **Purpose:** Centralized settings, localization strings, and reference recipe datasets.
- **Files:** `shared/config.lua`, `shared/locales.lua`, `shared/receita_nova.lua`, `shared/receita_tuning.lua`.
- **Responsibilities:** Framework toggles, progress bar types, target selection, translation tokens, and static recipe templates.

### 2. Framework Bridge (`bridge/`)
- **Purpose:** Abstract framework-dependent primitives into unified interfaces.
- **Files:**
  - `bridge/framework.lua`: Detects and initializes shared framework objects (`ESX` or `QBCore`).
  - `bridge/client/client.lua`: Defines client `QT` helper methods (`TriggerCallback`, `getjob`, `getgang`, `notification`, `progress`, `animation`).
  - `bridge/client/common.lua`: Core crafting lifecycle, table spawning, blip rendering, camera transitions, and interaction target attachment.
  - `bridge/client/raycast.lua`: Raycasting utility for precise 3D prop placement during table creation.
  - `bridge/server/server.lua`: Server `QT` methods (`RegisterCallback`, `GetFromId`, `GetJobs`, `GetGangs`, `AddItem`, `RemoveItem`, `HasItem`).
  - `bridge/server/insert.lua`: Database schema verification, auto-table creation, and schema column alterations.

### 3. Feature / Utility Layer (`cl_utils.lua`, `sv_utils.lua`)
- **Purpose:** Specific feature implementation for crafting table administration, recipe management, and crafting execution.
- **Files:**
  - `cl_utils.lua`: Admin menus for creating, moving, deleting, renaming tables, configuring recipes, item requirements, models, and animations.
  - `sv_utils.lua`: Server endpoints handling table creation, deletions, recipe persistence, skill reward distribution, and inventory transfer events.

## Data Flow

### Crafting Lifecycle Flow

1. **Player Interaction:**
   - Player approaches a crafting table prop in the game world.
   - `ox_target` checks job/gang constraints against `QT.getjob()` or `QT.getgang()`.
2. **Menu Retrieval:**
   - Client invokes server callback `forge-crafting:GetListItems` passing `craft_id`.
   - Client queries character crafting skill via `exports['forge-reputation']:getCurrentLevel`.
   - Client checks item recipe requirements against player inventory via `QT.HasItem` / `ox_inventory`.
3. **Crafting Initiation:**
   - Player selects an item and amount.
   - Client verifies ingredients and required skill level.
   - Client attaches preview prop / camera animation, plays animation (`animation(animDict)`), and starts `lib.progressCircle` / `lib.progressBar`.
4. **Completion & Fulfillment:**
   - Upon timer completion, client triggers server event `forge-crafting:ItemInterval`.
   - Server checks task validity (`IsValidTask`), removes recipe items (`QT.RemoveItem`), and adds output item (`QT.AddItem`).
   - Server triggers skill progression update via `forge-reputation`.

### Table Administration Flow

1. Admin executes `/create` or `/craft:create` (or opens `/edit`).
2. Server validates ACE permissions (`forge-crafting:PermisionCheck`).
3. Client initiates interactive prop placement using `raycast.lua`, allowing real-time positioning and rotation.
4. Client sends table metadata (`prop`, `coords`, `heading`, `blip`, `jobs`) to `forge-crafting:CreateWorkShop`.
5. Server persists table to `forge-crafting` SQL table and broadcasts update.

## Key Abstractions

- **`QT` Helper Library:**
  - Standardized wrapper table defined in both client (`bridge/client/client.lua`) and server (`bridge/server/server.lua`).
  - Encapsulates framework divergence for player objects, inventory calls, and event callbacks.
- **Recipe Data Structure:**
  - Standard JSON-encoded recipe schema in `forge-crafting-items` containing arrays of required materials (`{ item, label, amount }`), crafting duration (`time`), output count (`amount`), and unlock level (`level`).
- **Table Data Structure:**
  - Entity metadata schema in `forge-crafting` containing JSON blobs for coordinates, prop model, blip attributes, and authorized jobs/gangs.

## Entry Points

- **Resource Startup:**
  - Server: `bridge/server/insert.lua` on event `onServerResourceStart` ensures database tables and column additions exist.
  - Client: `bridge/client/common.lua` calls `CreateTables()` to fetch all active crafting tables and spawn world props.
- **Admin Commands:**
  - `Config.CreateTableCommand` (`create` / `craft:create`): Triggers `forge-crafting:CreateMenu`.
  - `Config.EditMenuCommand` (`edit` / `craft:edit`): Triggers `forge-crafting:EditMenu`.

## Error Handling

- Guard clauses checking framework object readiness.
- `pcall` wrappers around external exports (e.g. `forge-reputation` export calls) to prevent hard crashes if optional dependencies are missing.
- Input validation on client dialogs before triggering server mutations.
- Confirmation dialogs (`lib.alertDialog`) before destructive actions like table deletions or renaming.

---

*Architecture analysis: 2026-09-30*
*Update when major patterns change*
