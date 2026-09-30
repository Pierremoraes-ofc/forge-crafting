# Summary: Plan 02-02 - Ciclo de Vida de Entidades, Targeting e Blips Dinâmicos

## Resultado da Execução

- **Spawning Determinístico & Preservação de Altura/Rotação (`client.lua`):**
  - Carregamento de props protegido com `pr_lib.fivem.streaming.requestModel` e timeout defensivo de 3 segundos para evitar travamentos de thread caso um prop seja inválido.
  - Instanciação de entidades físicas usando `CreateObjectNoOffset` com `FreezeEntityPosition`, `SetEntityInvincible` e `SetEntityAsMissionEntity`.
  - Remoção de chamadas destrutivas a `PlaceObjectOnGroundProperly`: bancadas agora permanecem exatamente nas coordenadas X/Y/Z e rotação definidas pelo jogador no Gizmo 3D.

- **Targeting Estrito com `pr_lib.target` (`client.lua`):**
  - Registro de interação via `pr_lib.target.addLocalEntity` com nome identificador único, distância de 2.5 metros e validação de permissão de cargo/facção na função `canInteract`.
  - Limpeza formal e atômica implementada na função `CleanupWorldEntities`: desregistra cada prop do target (`pr_lib.target.removeLocalEntity`) antes de deletar a entidade (`DeleteObject`), tanto no evento `forge-crafting:Sync` quanto no `onResourceStop`.

- **Blips Dinâmicos e Reavaliação de Jobs/Gangues (`client.lua`):**
  - Isolamento do ciclo de blips na função `RefreshBlips(data)` com cache local de bancadas (`cachedWorkshops`).
  - Verificação de permissões do jogador normalizada para múltiplos formatos de payload (`pr_lib.framework.GetPlayerJob()`, `pr_lib.framework.GetPlayerGang()`).
  - Adicionados ouvintes para eventos de transição de profissão e facção (`QBCore:Client:OnJobUpdate`, `QBCore:Client:OnGangUpdate`, `esx:setJob`), atualizando a visibilidade dos blips em tempo real sem exigir restart do script.

## Requisitos Cobertos
- `WORLD-02`: Zonas de interação e target migradas para `pr_lib.target.addLocalEntity` e `removeLocalEntity`.
- `WORLD-03`: Ciclo de vida e integridade física de entidades garantido sem memory leak ou objetos órfãos.
- `WORLD-04`: Suporte a blips dinâmicos com filtragem por permissão de job e gangue via `pr_lib.framework`.
