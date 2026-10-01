# Summary: Plan 04-01 - Backend Autoritativo de Crafting e Sessões Seguras

## Resultado da Execução

- **Expurgo do Evento Vulnerável `ItemInterval` (`sv_utils.lua`):**
  - Removido integralmente o listener `RegisterNetEvent("forge-crafting:ItemInterval")` que permitia injeção e entrega arbitrária de itens por clientes.

- **Gerenciador de Sessões Autoritativas de Crafting (`activeCraftSessions`):**
  - **Início Seguro (`forge-crafting:StartCraft`):**
    - Verificação rigorosa de distância física entre o jogador e as coordenadas salvas da bancada (`#(playerCoords - benchCoords) <= 4.5m`).
    - Validação de restrição de cargos/gangues no servidor (`isPlayerAuthorizedForBench`).
    - Carregamento autoritativo da receita oficial diretamente do banco de dados MySQL via `pr_lib.db.single` (o cliente não dita quantidades nem ingredientes).
    - Validação de nível mínimo de maestria via `forge-reputation`.
    - Verificação de posse de todos os insumos via `pr_lib.inventory.GetItemCount`.
    - Consumo imediato e atômico de materiais via `pr_lib.inventory.RemoveItem`.
    - Registro de sessão ativa com timestamp de início do servidor (`GetGameTimer()`).

- **Finalização e Cancelamento com Reembolso Garantido:**
  - **Finalização Segura (`forge-crafting:FinishCraft`):**
    - Validação temporal autoritativa contra speedhacks (`GetGameTimer() - session.startTime >= expectedMs - 1500`).
    - Verificação persistente de proximidade física da bancada.
    - Entrega do item fabricado com quantidade oficial via `pr_lib.inventory.AddItem`.
    - Concessão de experiência de maestria via `forge-reputation`.
    - Limpeza da sessão ativa.
  - **Cancelamento (`forge-crafting:CancelCraft`):**
    - Reembolso e devolução imediata de todos os ingredientes consumidos de volta ao inventário do jogador.
  - **Desconexão Segura (`playerDropped`):**
    - Caso o jogador caia durante o craft, os materiais consumidos são devolvidos ao seu inventário e a sessão é liberada.

## Requisitos Cobertos
- `CRAFT-01`: Validação autoritativa de crafting 100% no servidor (proximidade, receita oficial, maestria).
- `CRAFT-02`: Checagem e consumo seguro de insumos via `pr_lib.inventory`.
- `CRAFT-03`: Entrega segura do produto final via `pr_lib.inventory.AddItem` após validação estrita de tempo e integridade.
