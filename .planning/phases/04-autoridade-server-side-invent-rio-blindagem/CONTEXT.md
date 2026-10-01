# Contexto da Fase 4: Autoridade Server-side, Inventário & Blindagem

## Objetivo
Eliminar vulnerabilidades críticas de segurança no ciclo de crafting. Erradicar o evento legado `forge-crafting:ItemInterval`, transferindo 100% da autoridade de verificação de receitas, proximidade física, consumo e entrega de itens para o servidor. Integrar temporizadores visuais imersivos via `pr_lib.progressBar` e concessão balanceada de experiência via `forge-reputation`.

## Escopo & Decisões Arquiteturais

1. **Eliminação do `ItemInterval` & Sessões Autoritativas (`CRAFT-01`, `CRAFT-03`):**
   - O evento `forge-crafting:ItemInterval` que permitia injeção arbitrária de itens (`task, item, count`) é completamente deletado.
   - O cliente passa a solicitar a fabricação enviando apenas o `craft_id` da bancada e o identificador do item (`item_name`).
   - O servidor consulta a receita oficial cadastrada no banco de dados e calcula a distância física entre o jogador e as coordenadas registradas daquela bancada.
   - O servidor inicia uma sessão ativa com timestamp de início e tempo total de preparo:
     `activeCraftSessions[source] = { craft_id = ..., item = ..., amount = ..., recipe = ..., duration = ..., startTime = os.time() }`.

2. **Consumo e Reembolso Seguro de Insumos (`CRAFT-02`):**
   - Antes de iniciar a fabricação, o servidor valida se o jogador possui todos os ingredientes em quantidade suficiente no inventário (`pr_lib.inventory.GetItemCount`).
   - Os insumos são consumidos imediatamente pelo servidor (`pr_lib.inventory.RemoveItem`).
   - Caso o jogador cancele o progresso (tecla ESC, movimento, morte ou desconexão), o servidor processa o cancelamento e devolve integralmente os materiais consumidos (`pr_lib.inventory.AddItem`).

3. **Validação Temporal e Entrega com Maestria (`CRAFT-03`, `CRAFT-04`, `CRAFT-05`):**
   - Ao término do tempo, o cliente solicita a finalização da sessão.
   - O servidor valida se o tempo transcorrido é compatível com a receita (`tempo real >= tempo receita - 1 segundo`), prevenindo exploits de avanço de tempo ou cancelamentos simulados.
   - O servidor adiciona o item pronto ao inventário do jogador (`pr_lib.inventory.AddItem`) e premia a experiência na habilidade correspondente via `forge-reputation`.
   - O cliente exibe animações contextualizadas e a barra de progresso nativa do `pr_bridge` (`pr_lib.progressBar`).
