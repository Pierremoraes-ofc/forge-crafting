# Structure

**Analysis Date:** 2026-09-30

## Directory Layout

```
forge-crafting/
├── fxmanifest.lua               # Resource manifest (fx_version cerulean, lua54)
├── cl_utils.lua                 # Client management, menus, dialogs, item setup
├── sv_utils.lua                 # Server callbacks, table/item events, skill hooks
├── bridge/
│   ├── framework.lua            # Framework detection and core object export loader
│   ├── client/
│   │   ├── client.lua           # Client-side QT abstractions, notifications, progress
│   │   ├── common.lua           # Table spawning, blip creation, ox_target setup, crafting menu
│   │   └── raycast.lua          # Camera raycast vector calculation for table placement
│   └── server/
│       ├── insert.lua           # Database schema auto-creation and column migrations
│       └── server.lua           # Server-side QT abstractions, callbacks, inventory bridge
└── shared/
    ├── config.lua               # Main resource configuration and parameters
    ├── locales.lua              # Translation and UI localized text strings
    ├── receita_nova.lua         # Reference recipe dataset in Lua format
    ├── receita_nova.sql         # SQL dump for importing 'Pecas Novas' recipes
    └── receita_tuning.lua       # Reference tuning recipe dataset in Lua format
```

## Key Locations & Responsibilities

| Path | Primary Responsibility | Key Functions / Exports |
|------|------------------------|-------------------------|
| `fxmanifest.lua` | Resource manifest & load sequence | `shared_scripts`, `client_scripts`, `server_scripts`, `dependencies` |
| `shared/config.lua` | Global settings | `Config.Framework`, `Config.Target`, `Config.OxProgress`, `Config.ImagePath` |
| `shared/locales.lua` | UI text & messages | `locales` table |
| `bridge/framework.lua` | Framework resolution | Initializes `ESX` or `QBCore` shared object |
| `bridge/client/client.lua` | Client bridge abstractions | `notification()`, `progress()`, `QT.TriggerCallback`, `QT.getjob` |
| `bridge/client/common.lua` | World entity & crafting loop | `CreateTables()`, `CraftMenu()`, `BlipCreation()`, `exports.ox_target` |
| `bridge/client/raycast.lua` | Raycasting 3D math | `RayCastGamePlayCamera()`, `RotationToDirection()` |
| `bridge/server/server.lua` | Server bridge abstractions | `QT.RegisterCallback`, `QT.AddItem`, `QT.RemoveItem`, `QT.HasItem` |
| `bridge/server/insert.lua` | SQL DDL & schema migrations | `CREATE TABLE IF NOT EXISTS`, `ALTER TABLE` checks on startup |
| `cl_utils.lua` | Interactive admin & recipe UI | `forge-crafting:CreateMenu`, `forge-crafting:EditMenu`, `lib.registerContext` |
| `sv_utils.lua` | Server event handlers & sync | `forge-crafting:CreateWorkShop`, `forge-crafting:ItemInterval`, `addCraftingSkill` |

## Naming & File Conventions

- **File Naming:**
  - Prefix-based naming for client/server entry points (`cl_utils.lua`, `sv_utils.lua`).
  - Categorized subdirectories for bridge layers (`bridge/client/`, `bridge/server/`).
  - Shared files located under `shared/`.
- **Event Naming:**
  - Standard resource prefix namespace: `forge-crafting:<EventName>` (e.g., `forge-crafting:CreateWorkShop`, `forge-crafting:ItemInterval`, `forge-crafting:GetList`).
- **Database Tables:**
  - Hyphenated naming: `forge-crafting` (tables/workshops) and `forge-crafting-items` (recipes).
- **Variable & Function Conventions:**
  - Global `Config` table in uppercase PascalCase.
  - Global `QT` table in uppercase abbreviations.
  - Local helper functions in camelCase (`addCraftingSkill`) or snake_case (`server_notification`).

---

*Structure analysis: 2026-09-30*
*Update after directory restructuring*
