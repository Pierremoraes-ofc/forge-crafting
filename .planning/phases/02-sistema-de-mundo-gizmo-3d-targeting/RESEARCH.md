# Pesquisa Técnica: Fase 2 - Sistema de Mundo, Gizmo 3D & Targeting

## 1. Padrões de Gizmo no `pr_bridge`

Conforme inspecionado em `pr_scriptTest` (`client_manifest.lua` e `client.lua`), o módulo Gizmo do `pr_bridge` disponibiliza uma API modal assíncrona moderna:

```lua
local gizmoApi = (pr_lib.fivem and pr_lib.fivem.gizmo) or pr_lib.gizmo

local confirmedResult, finalResult = gizmoApi.await(object, {
    title = "Posicionar Bancada",
    offset = vector3(0.0, 0.0, 0.0),
    precisionMode = false,
    precisionSpeed = 1.0,
    allowFreeCameraToggle = true,
    restoreOnCancel = true,
    ui = true,
    onUpdate = function()
        return true
    end,
})

local result = confirmedResult or finalResult or { confirmed = false, reason = "sem_resultado" }
if result.confirmed then
    local coords = result.coords or GetEntityCoords(object)
    local rotation = result.rotation or GetEntityRotation(object, 2)
    local heading = rotation.z or GetEntityHeading(object)
    -- Persistir novas coordenadas
end
```

### Principais Características
- **Controles embutidos:** Suporta arrastar eixos X/Y/Z, girar Yaw/Pitch/Roll, alternar sensibilidade / precisão via `TAB`.
- **Restauração em cancelamento:** `restoreOnCancel = true` restaura o estado original da entidade caso o usuário cancele com ESC ou Backspace.
- **Limpeza:** A entidade de preview deve ser criada sem colisão (`SetEntityCollision(obj, false, false)`), congelada (`FreezeEntityPosition(obj, true)`) e devidamente excluída após o término da sessão do Gizmo.

---

## 2. Padrões de Target (`pr_lib.target`)

A API de target nativa do `pr_bridge` segue o padrão:

```lua
pr_lib.target.addLocalEntity(propobj, {
    {
        name = 'table_' .. tableId,
        label = 'Acessar ' .. tableName,
        icon = 'fa-solid fa-hammer',
        distance = 2.5,
        canInteract = function(entity)
            if isBusy then return false end
            -- Checagem de cargo / gangue
            return true
        end,
        onSelect = function(entityData)
            -- Abertura da interface / menu
        end
    }
})

-- Remoção estrita:
pr_lib.target.removeLocalEntity(propobj)
```

---

## 3. Streaming de Modelos (`pr_lib.fivem.streaming`)

O `pr_bridge` oferece helpers de streaming para carregar e descarregar props com segurança sem travar a thread do jogo:

```lua
local streaming = pr_lib.fivem and pr_lib.fivem.streaming
if streaming and streaming.requestModel then
    local loaded, modelHash = streaming.requestModel(modelName, 3000)
    -- Uso do modelHash
    streaming.releaseModel(modelHash)
else
    -- Fallback nativo
    local modelHash = type(modelName) == "string" and joaat(modelName) or modelName
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end
end
```

---

## 4. Reavaliação de Jobs & Gangues

O `pr_lib.framework` disponibiliza:
- `pr_lib.framework.GetPlayerJob()` -> `{ name = "police", grade = 1 }` ou string de nome.
- `pr_lib.framework.GetPlayerGang()` -> `{ name = "ballas", grade = 1 }` ou string de nome.
- Eventos nativos comuns disparados pelas frameworks ao trocar de emprego ou gangue:
  - `QBCore:Client:OnJobUpdate` / `QBCore:Client:OnGangUpdate`
  - `esx:setJob`
Registrando listeners nesses eventos permite que o cliente reconstrua os Blips do jogador sem necessidade de reiniciar o script.
