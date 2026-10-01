# Summary: Plan 04-02 - Integração Client-side de Crafting com Progress Bar e Cancelamento

## Resultado da Execução

- **Refatoração do Fluxo de Crafting no Cliente (`client.lua`):**
  - Ajustado `previewCraftable` para repassar o identificador unívoco da bancada (`craft_id = data.menu_id`) para o contexto de confirmação e disparo de fabricação.
  - Substituída a lógica vulnerável e de intervalos legados em `forge-crafting:CraftCertainItem` por um pipeline assíncrono blindado.

- **Pipeline Assíncrono com `pr_lib.progressBar`:**
  - **Solicitação de Início:** Dispara `pr_lib.callback.await("forge-crafting:StartCraft", false, craftId, itemName, multiplier)` ao servidor.
  - **Tratamento de Recusa:** Se o servidor recusar (materiais insuficientes, nível baixo, longe da bancada), notifica o usuário via `pr_lib.notify` e encerra com segurança sem animações fantasmas.
  - **Execução Visual e Restrições Físicas:**
    - Executa a barra de progresso nativa `pr_lib.progressBar({ duration = totalDuration, label = ..., useWhileDead = false, canCancel = true, disable = { car = true, move = true, combat = true } })`.
    - Executa animações de oficina e partículas de forja associadas à bancada.
  - **Tratamento de Sucesso:**
    - Se a barra terminar normalmente sem cancelamento ou morte, solicita `pr_lib.callback.await("forge-crafting:FinishCraft", false)`.
    - Limpa props, tarefas de animação e notifica sucesso ao jogador.
  - **Cancelamento e Segurança contra Abusos:**
    - Se o jogador cancelar a barra (ou morrer/desconectar), o client dispara `TriggerServerEvent("forge-crafting:CancelCraft")`.
    - O servidor cancela a sessão e reembolsa 100% dos materiais consumidos no inventário do jogador.

## Requisitos Cobertos
- `CRAFT-02`: Consumo e reembolso de materiais com feedback visual sincronizado.
- `CRAFT-03`: Execução de `pr_lib.progressBar` com proteção contra movimentação/combate e validação de finalização autoritativa.
