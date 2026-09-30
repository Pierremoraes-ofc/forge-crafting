# Coding Conventions

**Analysis Date:** 2026-09-30

## Code Style & Formatting

- **Indentation:** 4 spaces across all `.lua` source files.
- **Language Level:** Lua 5.4 features enabled (`lua54 'yes'` in `fxmanifest.lua`).
- **Table Insertion Idiom:** Uses custom `insert` function (`t[#t + 1] = v`) instead of `table.insert` for micro-optimization during array building.
- **Strings:** Double quotes and single quotes are both present, with single quotes favored for FiveM native event names and ox_lib identifiers.
- **JSON Serialization:** Uses native `json.encode()` and `json.decode()` for serializing complex table parameters and blip definitions.

## Naming Conventions

- **Global Configuration:** Global `Config` table, properties in PascalCase or camelCase (e.g. `Config.Framework`, `Config.CreateTableCommand`, `Config.OxProgress`).
- **Global Abstraction Bridge:** Global `QT` namespace containing cross-framework functions (`QT.TriggerCallback`, `QT.RegisterCallback`, `QT.GetFromId`, `QT.AddItem`).
- **Localization:** Global `locales` table populated from `shared/locales.lua`.
- **Functions:**
  - Local functions generally use camelCase or snake_case (e.g. `addCraftingSkill`, `server_notification`, `registerCraftingCommand`).
  - Bridge methods use PascalCase or camelCase (`TriggerCallback`, `getjob`, `getgang`).
- **Events & Callbacks:**
  - Prefixed with resource namespace: `forge-crafting:<Action>` (e.g. `forge-crafting:GetList`, `forge-crafting:CreateWorkShop`).
- **Context IDs & Target Names:**
  - Snake_case identifiers (e.g. `crafting_list`, `edit_opcije`, `table_<id>`).

## Patterns & Idioms

- **Bridge Pattern:**
  - All framework checks branch on `if ESX ~= nil then ... elseif QBCore ~= nil then ... end`.
  - Core objects are resolved once at startup in `bridge/framework.lua`.
- **Resource Dependency Guards:**
  - Checks state of external resources using `GetResourceState(resource) ~= 'started'` and protects calls with `pcall()`.
- **Micro-Optimizations:**
  - Local caching of raycast utility via `lib.require('bridge.client.raycast')`.
  - Model asset cleanup using `SetModelAsNoLongerNeeded(model)` after prop spawning.
- **Client UI Delegation:**
  - Delegation of UI views to `ox_lib` context menus (`lib.registerContext` / `lib.showContext`) and alert modals (`lib.alertDialog`).

## Error Handling & Validation

- **Permission Checking:**
  - Server callbacks check ACE permissions (`IsPlayerAceAllowed`) before exposing admin actions.
  - Client checks permissions via `QT.TriggerCallback('forge-crafting:PermisionCheck')` before displaying admin context menus.
- **Task Validation:**
  - `IsValidTask(task)` checks valid operation tokens (`"add"` / `"remove"`) before executing inventory mutations.
- **SQL Sanitization:**
  - Uses parameterized queries (`@craft_id`, `@craft_name`, `?` placeholder) via `oxmysql` to avoid SQL injection.
- **User Cancellation Handling:**
  - Interactive dialogues check for `nil` or cancelled inputs, redirecting back to the parent context menu smoothly.

---

*Conventions analysis: 2026-09-30*
*Update when coding standards change*
