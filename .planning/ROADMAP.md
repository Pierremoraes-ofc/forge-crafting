# Roadmap: Forge Crafting

## Overview

Este roadmap estrutura a transformação completa do **forge-crafting** em um recurso FiveM verdadeiramente standalone e nativo do ecossistema Forge-Core. O script elimina totalmente as dependências legadas de `ox_lib`, `ox_target` e `oxmysql`, adotando o `pr_bridge` de forma direta e sem wrappers, integrando o Gizmo 3D para posicionamento de bancadas, blindando a segurança com validação autoritativa no servidor e finalizando com uma nova interface visual NUI dedicada para a bancada de trabalho.

## Phases

- [x] **Phase 1: Desacoplamento & Fundação pr_bridge** - Remover dependências externas, carregar @pr_bridge/init.lua, expurgar wrappers legados e migrar banco para pr_lib.db.
- [x] **Phase 2: Sistema de Mundo, Gizmo 3D & Targeting** - Implementar posicionamento com Gizmo modal (pr_lib.gizmo.await), ciclo de vida dos props e targeting com pr_lib.target.
- [x] **Phase 3: Gestão Administrativa & Menus pr_bridge** - Migrar menus de criação/edição/exclusão de bancadas para os contextos, dialogs e alertas nativos do pr_bridge.
- [ ] **Phase 4: Autoridade Server-side, Inventário & Blindagem** - Refatorar o ciclo de vida do crafting com validação autoritativa no servidor via pr_lib.inventory e pr_lib.callback.
- [ ] **Phase 5: Nova NUI da Bancada de Craft** - Desenvolver e integrar a interface gráfica NUI interativa para fabricação de receitas diretamente na bancada.

## Phase Details

### Phase 1: Desacoplamento & Fundação pr_bridge
**Goal**: Tornar o recurso independente de ox_lib, oxmysql e ox_target, preparando o ambiente para consumo direto de pr_lib.
**Depends on**: Nothing (primeira fase)
**Requirements**: DEPS-01, DEPS-02, DEPS-03, DB-01, DB-02, DB-03
**Success Criteria** (o que deve ser VERDADEIRO):
  1. O arquivo `fxmanifest.lua` não possui referências a `ox_lib`, `oxmysql` ou `ox_target` e carrega `@pr_bridge/init.lua`.
  2. A pasta `bridge/` legada do forge-crafting é removida e a tabela global `QT` é expurgada em favor de `pr_lib`.
  3. A criação das tabelas `forge-crafting` e `forge-crafting-items` e suas consultas executam sem erros via `pr_lib.db`.
**Plans**: 2 plans

Plans:
- [x] 01-01: Limpeza de manifest, remoção de dependências legadas e expurgo da pasta bridge/wrapper.
- [x] 01-02: Migração do schema e das consultas SQL para `pr_lib.db` com auto-increment.

### Phase 2: Sistema de Mundo, Gizmo 3D & Targeting
**Goal**: Gerenciar a presença física das bancadas de trabalho no mundo do jogo com ferramentas modernas do pr_bridge.
**Depends on**: Phase 1
**Requirements**: WORLD-01, WORLD-02, WORLD-03, WORLD-04
**Success Criteria** (o que deve ser VERDADEIRO):
  1. Administradores posicionam e rotacionam novas bancadas usando o Gizmo 3D (`pr_lib.gizmo.await`).
  2. As bancadas spawnadas recebem zonas de interação através de `pr_lib.target.addLocalEntity`.
  3. Ao parar o recurso ou deletar uma bancada, entidades e targets são limpos adequadamente sem deixar objetos órfãos.
**Plans**: 2 plans

Plans:
- [x] 02-01: Implementação da colocação e rotação de bancadas via `pr_lib.gizmo.await`.
- [x] 02-02: Spawning de entidades, sincronização de blips com permissões e registro via `pr_lib.target`.

### Phase 3: Gestão Administrativa & Menus pr_bridge
**Goal**: Fornecer a interface administrativa de gerenciamento de bancadas utilizando exclusivamente o sistema de UI do pr_bridge.
**Depends on**: Phase 2
**Requirements**: ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-04
**Success Criteria** (o que deve ser VERDADEIRO):
  1. Comandos `/create` e `/edit` abrem menus de contexto nativos do `pr_bridge` (`pr_lib.RegisterContext`).
  2. Edição de nomes e atributos de bancada funciona através de `pr_lib.inputDialog` e `pr_lib.alertDialog`.
  3. Notificações operam através de `pr_lib.notifications.Notify` e `pr_lib.notifications.NotifyPlayer`.
**Plans**: 2 plans

Plans:
- [x] 03-01: Migração dos menus de criação e listagem para `pr_lib.RegisterContext` e dialogs.
- [x] 03-02: Padronização de comandos, permissões ACE e mensagens de notificação do pr_bridge.

### Phase 4: Autoridade Server-side, Inventário & Blindagem
**Goal**: Eliminar falhas de segurança no crafting, garantindo validação estrita e consumo/entrega segura de itens no servidor.
**Depends on**: Phase 3
**Requirements**: CRAFT-01, CRAFT-02, CRAFT-03, CRAFT-04, CRAFT-05
**Success Criteria** (o que deve ser VERDADEIRO):
  1. O evento `forge-crafting:ItemInterval` não permite injeção arbitrária de itens; toda entrega é validada e executada pelo servidor.
  2. Itens são checados e consumidos via `pr_lib.inventory.HasItem` e `pr_lib.inventory.RemoveItem`.
  3. Temporizadores de fabricação utilizam `pr_lib.progressBar` / `pr_lib.progressCircle` e premiam reputação via `forge-reputation`.
**Plans**: 2 plans

Plans:
- [ ] 04-01: Refatoração do backend de crafting com validação de proximidade, insumos e níveis no servidor.
- [ ] 04-02: Conexão do client com temporizadores e animações do `pr_bridge` e concessão de XP.

### Phase 5: Nova NUI da Bancada de Craft
**Goal**: Criar uma interface NUI imersiva e moderna para a bancada de trabalho, substituindo o menu de contexto padrão dos jogadores.
**Depends on**: Phase 4
**Requirements**: NUI-01, NUI-02, NUI-03
**Success Criteria** (o que deve ser VERDADEIRO):
  1. Ao interagir com a bancada no target, a NUI customizada de crafting é exibida com visual temático de bancada.
  2. O jogador pode navegar pelas receitas, visualizar insumos requeridos (com contagem atual vs necessária) e iniciar a fabricação.
  3. A interface fecha corretamente com ESC ou botão de fechar, restaurando controles do jogo sem bugs de foco.
**Plans**: 2 plans

Plans:
- [ ] 05-01: Estruturação dos componentes de front-end (HTML/CSS/JS) da NUI de bancada de craft.
- [ ] 05-02: Integração dos eventos NUI com o client Lua do forge-crafting e testes de fluxo completo.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Desacoplamento & Fundação pr_bridge | 2/2 | Complete | 2026-09-30 |
| 2. Sistema de Mundo, Gizmo 3D & Targeting | 2/2 | Complete | 2026-09-30 |
| 3. Gestão Administrativa & Menus pr_bridge | 2/2 | Complete | 2026-09-30 |
| 4. Autoridade Server-side, Inventário & Blindagem | 0/2 | Not started | - |
| 5. Nova NUI da Bancada de Craft | 0/2 | Not started | - |
