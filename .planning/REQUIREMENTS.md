# Requirements: Forge Crafting

**Defined:** 2026-09-30
**Core Value:** Independência total e arquitetura standalone limpa através do `pr_bridge`, eliminando completamente dependências externas (`ox_lib`, `ox_target`, `oxmysql`) e usando chamadas diretas às APIs nativas da bridge com validação segura no servidor e NUI imersiva.

## v1 Requirements

### Desacoplamento & Fundação (DEPS)

- [ ] **DEPS-01**: Atualizar `fxmanifest.lua` removendo todas as dependências de `ox_lib`, `ox_target` e `oxmysql`.
- [ ] **DEPS-02**: Configurar `pr_bridge` como dependência exclusiva (`dependency 'pr_bridge'` e `@pr_bridge/init.lua` em `shared_scripts`).
- [ ] **DEPS-03**: Excluir a pasta `bridge/` legada do forge-crafting e eliminar o wrapper global `QT`, passando a invocar diretamente `pr_lib.*`.

### Banco de Dados Universal (DB)

- [ ] **DB-01**: Migrar inicialização de schemas (`forge-crafting` e `forge-crafting-items`) para `pr_lib.db.execute` / `pr_lib.db.query`.
- [ ] **DB-02**: Migrar consultas de bancadas e itens para `pr_lib.db.query` e `pr_lib.db.single` com suporte transparente a qualquer driver SQL configurado no servidor.
- [ ] **DB-03**: Ajustar a inserção de novas bancadas para utilizar o auto-increment nativo da base em vez de IDs randômicos manuais.

### Sistema de Mundo, Gizmo & Targeting (WORLD)

- [ ] **WORLD-01**: Integrar `pr_lib.gizmo.await` para posicionamento e rotação tridimensional de props de bancadas, eliminando o raycast manual e loops de teclas legados.
- [ ] **WORLD-02**: Migrar zonas de interação das bancadas no mundo para `pr_lib.target.addLocalEntity` e `pr_lib.target.removeLocalEntity`.
- [ ] **WORLD-03**: Gerenciar ciclo de vida das entidades físicas no mapa (spawning, congelamento, posicionamento no solo e cleanup no stop do recurso).
- [ ] **WORLD-04**: Suporte a blips no mapa com filtragem por permissão de job/gangue via `pr_lib.framework`.

### Gestão Administrativa & Interface (ADMIN)

- [ ] **ADMIN-01**: Adaptar menus de administração de bancadas (`/create` e `/edit`) para `pr_lib.RegisterContext` e `pr_lib.showContext`.
- [ ] **ADMIN-02**: Utilizar `pr_lib.inputDialog` para entradas de dados (nomes de mesa, parâmetros de receita) e `pr_lib.alertDialog` para confirmações de exclusão.
- [ ] **ADMIN-03**: Padronizar notificações para `pr_lib.notifications.Notify` (client) e `pr_lib.notifications.NotifyPlayer` (server), corrigindo discrepâncias de chaves de tradução.
- [ ] **ADMIN-04**: Validação de permissões de comando através das checagens nativas de ACE / permissões do `pr_lib`.

### Segurança, Inventário & Crafting Server-side (CRAFT)

- [ ] **CRAFT-01**: Validação autoritativa de crafting 100% no servidor (distância da bancada, posse de receita válida e checagem de nível de habilidade).
- [ ] **CRAFT-02**: Checagem e remoção segura de insumos necessários via `pr_lib.inventory.HasItem` e `pr_lib.inventory.RemoveItem`.
- [ ] **CRAFT-03**: Entrega do item fabricado com `pr_lib.inventory.AddItem` após confirmação do término do tempo, bloqueando qualquer injeção arbitrária de itens por clientes.
- [ ] **CRAFT-04**: Temporizadores de ação com suporte a barra de progresso nativa (`pr_lib.progressBar` / `pr_lib.progressCircle`).
- [ ] **CRAFT-05**: Atualização de experiência de crafting integrada ao `forge-reputation`.

### Interface Visual Dedicada (NUI)

- [ ] **NUI-01**: Desenvolver NUI moderna e responsiva (inspirada no conceito de bancada do `nextgenfivem_crafting`) para interação do jogador com o crafting.
- [ ] **NUI-02**: Exibir catálogo de receitas, tempo de preparo, insumos necessários (com contagem atual vs requerida) e nível mínimo exigido.
- [ ] **NUI-03**: Comunicação bidirecional NUI ↔ Client (abrir, fechar, selecionar receita, iniciar craft e feedback visual).

## v2 Requirements

### Recursos Avançados

- **ADV-01**: Renderização de tela DUI em 3D sobre o prop da bancada via `pr_lib.dui`.
- **ADV-02**: Sistema de blueprints / receitas descobríveis via itens consumíveis.
- **ADV-03**: Minigame de skillcheck integrado via `pr_lib.ox.skillCheck` ou minigames nativos do `pr_bridge` durante o crafting.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Wrappers ou adaptadores intermediários | O código deve consumir `pr_lib.*` de forma direta e limpa |
| Manutenção de suporte legado a ox_lib e ox_target | A base Forge-Core usa sua própria interface e o pr_bridge para compatibilidade |
| Criação de novas funções utilitárias que já existem na bridge | Prioridade máxima no reúso do ecossistema já fornecido pelo `pr_bridge` |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEPS-01 | Phase 1 | Pending |
| DEPS-02 | Phase 1 | Pending |
| DEPS-03 | Phase 1 | Pending |
| DB-01 | Phase 1 | Pending |
| DB-02 | Phase 1 | Pending |
| DB-03 | Phase 1 | Pending |
| WORLD-01 | Phase 2 | Pending |
| WORLD-02 | Phase 2 | Pending |
| WORLD-03 | Phase 2 | Pending |
| WORLD-04 | Phase 2 | Pending |
| ADMIN-01 | Phase 3 | Pending |
| ADMIN-02 | Phase 3 | Pending |
| ADMIN-03 | Phase 3 | Pending |
| ADMIN-04 | Phase 3 | Pending |
| CRAFT-01 | Phase 4 | Pending |
| CRAFT-02 | Phase 4 | Pending |
| CRAFT-03 | Phase 4 | Pending |
| CRAFT-04 | Phase 4 | Pending |
| CRAFT-05 | Phase 4 | Pending |
| NUI-01 | Phase 5 | Pending |
| NUI-02 | Phase 5 | Pending |
| NUI-03 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0 ✓

---
*Requirements defined: 2026-09-30*
*Last updated: 2026-09-30 after initial definition*
