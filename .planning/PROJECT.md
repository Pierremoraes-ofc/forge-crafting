# Forge Crafting

## What This Is

O **forge-crafting** é o sistema oficial de crafting para a framework própria do Forge-Core no FiveM. O recurso permite aos administradores criar, configurar e posicionar bancadas de trabalho tridimensionais no mapa, e aos jogadores fabricar peças, itens e melhorias através de uma interface interativa diretamente sobre a bancada, com progressão atrelada a níveis de habilidade.

## Core Value

Independência total e arquitetura standalone limpa através do `pr_bridge`, eliminando completamente dependências externas (`ox_lib`, `ox_target`, `oxmysql`) e usando chamadas diretas às APIs nativas da bridge com validação segura no servidor e NUI imersiva.

## Requirements

### Validated

- ✓ Criação e persistência de bancadas de trabalho no banco de dados — existing
- ✓ Estrutura de receitas com materiais, tempo, quantidade e níveis (`shared/receita_nova.lua`, `shared/receita_tuning.lua`) — existing
- ✓ Integração de experiência e progresso com `forge-reputation` — existing

### Active

- [ ] **Desacoplamento e Dependências:** Remodelar `fxmanifest.lua` removendo `ox_lib`, `oxmysql` e `ox_target`, estabelecendo `pr_bridge` (`@pr_bridge/init.lua`) como única dependência compartilhada.
- [ ] **Banco de Dados Universal:** Migrar todas as operações de banco de dados (`insert.lua`, consultas e mutações) para `pr_lib.db` (`query`, `single`, `insert`, `execute`, `transaction`), suportando oxmysql, ghmattimysql ou mysql-async transparentemente.
- [ ] **Targeting Nativo:** Migrar o registro e desregistro de zonas de interação das bancadas do `ox_target` para `pr_lib.target` (`addLocalEntity`, `removeLocalEntity`).
- [ ] **UI Administrativa via pr_bridge:** Adaptar os menus administrativos de criação, edição e exclusão de mesas para os módulos nativos de interface do `pr_bridge` (`pr_lib.RegisterContext`, `pr_lib.inputDialog`, `pr_lib.alertDialog`, `pr_lib.notifications.Notify` / `NotifyPlayer`).
- [ ] **Gizmo 3D Nativo:** Substituir o sistema legado de raycast e loop de câmera pelo Gizmo 3D modal autocontido (`pr_lib.gizmo.await`) para posicionamento e rotação de bancadas.
- [ ] **Temporizadores de Crafting:** Substituir barras de progresso legadas por `pr_lib.progressBar` / `pr_lib.progressCircle`.
- [ ] **Limpeza de Wrappers:** Eliminar a pasta `bridge/` legada do forge-crafting e a tabela global intermediária `QT`, consumindo diretamente `pr_lib.inventory`, `pr_lib.callback`, `pr_lib.framework` e `pr_lib.cache`.
- [ ] **Segurança e Validação Server-Side:** Blindar o evento de fabricação de itens (`forge-crafting:ItemInterval`), transferindo a validação de proximidade, checagem de inventário, consumo de insumos e concessão de recompensas integralmente para o servidor.
- [ ] **Nova NUI / DUI de Crafting:** Desenvolver interface visual dedicada (NUI/DUI sobre a bancada no estilo de `nextgenfivem_crafting`) para substituir o menu de contexto padrão dos jogadores na seleção de receitas.

### Out of Scope

- **Wrappers intermediários:** Não criar funções intermediárias para envelopar o `pr_bridge`; o código deve ser direto e limpo chamando `pr_lib.*`.
- **Recriação de utilitários existentes:** Não reinventar funcionalidades que o `pr_bridge` já disponibiliza nativamente (gizmo, DUI, laser, inventário, cache, etc.).
- **Manutenção de ox_lib / ox_target:** Descarte total dessas dependências em favor da interface e target nativos do ecossistema Forge-Core.

## Context

- **Ecossistema:** Servidor FiveM Forge-Core operando com arquitetura standalone orientada a bridges.
- **Referências principais:**
  - `E:\[FIVEM]\Forge-Core\resources\[forge]\[forge-scripts]\pr_bridge` — biblioteca central de compatibilidade, banco, target, menus e ferramentas 3D.
  - `E:\[FIVEM]\Forge-Core\resources\[forge]\[forge-scripts]\pr_scriptTest` — implementação de referência com padrões recomendados de consumo do `pr_bridge`.
  - `E:\[FIVEM]\Forge-Core\resources\[Docs]\nextgenfivem_crafting` — referência visual e arquitetural de NUI/DUI para bancadas de crafting.
- **Diagnóstico da base atual:** Mapeamento completo registrado em `.planning/codebase/` com 7 documentos analisados.

## Constraints

- **Dependências:** Única dependência permitida de biblioteca é `pr_bridge`.
- **Estilo de Código:** Chamadas diretas a `pr_lib`, sem wrappers intermediários ou redundâncias.
- **Segurança:** Nenhuma entrega de item pode ser solicitada cegamente pelo cliente; toda a regra de negócio de consumo e entrega reside no servidor.
- **Compatibilidade:** Funcionamento transparente em qualquer framework suportada pelo `pr_bridge`.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Migração completa para `pr_bridge` | Garantir que o script seja standalone e compatível com todas as frameworks sem ox_lib/oxmysql | — Pending |
| Adoção de `pr_lib.gizmo.await` para colocação de mesas | Elimina rotinas legadas de raycast e controle manual de teclas no client | — Pending |
| Chamadas diretas sem wrapper `QT` | Simplifica drasticamente a arquitetura do código e reduz o consumo de tokens/memória | — Pending |
| Nova NUI sobre a bancada de craft | Eleva a imersão e experiência do usuário no padrão de qualidade do Forge-Core | — Pending |
| Autoridade total do servidor no crafting | Fecha vulnerabilidade crítica de injeção de itens por executores | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-09-30 after initialization*
