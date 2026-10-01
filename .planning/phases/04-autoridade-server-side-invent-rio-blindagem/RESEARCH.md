# Pesquisa Técnica: Fase 4 - Autoridade Server-side, Inventário & Blindagem

## 1. Padrões de Inventário do `pr_bridge` (`pr_lib.inventory`)

No servidor (`sv_utils.lua`), o módulo de inventário expõe:

```lua
-- Checar contagem de itens
local count = pr_lib.inventory.GetItemCount(source, itemName)

-- Checar se possui item em quantidade mínima
local hasItem = pr_lib.inventory.HasItem(source, itemName, minCount)

-- Adicionar item
local success = pr_lib.inventory.AddItem(source, itemName, amount, metadata, slot)

-- Remover item
local success = pr_lib.inventory.RemoveItem(source, itemName, amount, metadata, slot)
```

Ambos operam de forma transparente com qualquer sistema de inventário compatível (ox_inventory, qb-inventory, qs-inventory, ps-inventory).

---

## 2. Controle de Sessão de Crafting Server-side

Para garantir autoridade estrita e prevenir exploits:

```lua
local activeSessions = {}

-- Ao iniciar
activeSessions[source] = {
    craft_id = craft_id,
    item = item_name,
    amount = recipeRow.amount,
    time = recipeRow.time,
    consumed = consumedItemsList,
    startTime = GetGameTimer(),
    expectedDuration = recipeRow.time * 1000
}

-- Ao finalizar
local session = activeSessions[source]
if not session then return false, "Sessão inválida" end

local elapsed = GetGameTimer() - session.startTime
if elapsed < (session.expectedDuration - 1000) then
    -- Trapaça de tempo / Speedhack detectada
    return false, "Tempo insuficiente"
end

-- Ao desconectar (playerDropped)
AddEventHandler('playerDropped', function()
    local src = source
    local session = activeSessions[src]
    if session and session.consumed then
        for _, ing in ipairs(session.consumed) do
            pr_lib.inventory.AddItem(src, ing.item, ing.amount)
        end
    end
    activeSessions[src] = nil
end)
```

---

## 3. Padrões de Barra de Progresso no Cliente (`pr_lib.progressBar`)

```lua
local success = pr_lib.progressBar({
    duration = durationMs,
    label = locales.craftingg .. itemLabel,
    useWhileDead = false,
    canCancel = true,
    disable = {
        car = true,
        move = true,
        combat = true,
        mouse = false
    },
    anim = {
        dict = animDict,
        clip = animClip
    }
})

if success then
    -- Notifica finalização ao servidor
else
    -- Notifica cancelamento ao servidor para reembolso
end
```

---

## 4. Integração com `forge-reputation`

```lua
local function addCraftingSkill(source)
    local resource = Config.ReputationResource or 'forge-reputation'
    if GetResourceState(resource) ~= 'started' then return end

    pcall(function()
        exports[resource]:updateSkill(source, Config.CraftingSkill or 'crafting', Config.CraftingSkillReward or 5)
    end)
end
```
