# Contexto da Fase 3: Gestão Administrativa & Menus pr_bridge

## Objetivo
Modernizar a interface de gerenciamento administrativo de bancadas de trabalho e receitas do `forge-crafting`. Todos os fluxos de criação, personalização de atributos (nomes, props, alturas, blips, jobs/gangues), gerenciamento de receitas e exclusão serão padronizados com os componentes nativos do `pr_bridge` (`pr_lib.RegisterContext`, `pr_lib.showContext`, `pr_lib.inputDialog`, `pr_lib.alertDialog`), com controle de permissão estrito via ACE e notificações consistentes e traduzidas.

## Escopo & Decisões Arquiteturais

1. **Contextos & Diálogos com `pr_lib` (`ADMIN-01`, `ADMIN-02`):**
   - Substituição de estruturas redundantes por uma árvore de menus hierárquica navegável (`menu = parent_id`), permitindo retorno suave em todos os níveis.
   - Formulários com validação estrita utilizando `pr_lib.inputDialog` (campos obrigatórios, limites de tempo/quantidade, select com busca de itens do inventário).
   - Confirmações de ações destrutivas (excluir mesa, excluir item de receita) operando com `pr_lib.alertDialog` centralizado e botões de confirmação/cancelamento claros.

2. **Comandos & Permissões ACE (`ADMIN-04`):**
   - Registro de comandos administrativos (`/create`, `/edit` e seus aliases prefixados) garantindo que apenas administradores com ACE (`group.admin`, `crafting` ou permissão de comando configurada) possam invocar a interface.
   - Validação autoritativa em dois níveis: no disparo do comando e no callback `forge-crafting:PermisionCheck`.

3. **Padronização de Notificações e Dicionário de Idiomas (`ADMIN-03`):**
   - Padronização em wrappers diretos que chamam `pr_lib.notifications.Notify` (client) e `pr_lib.notifications.NotifyPlayer` (server).
   - Auditoria completa de `shared/locales.lua`: adição de todas as chaves referenciadas no código que estavam ausentes (`press_edit_item`, `delete_item`, `desc_deleting_item`, `sure_delete_item`, etc.), correção de discrepâncias gramaticais e unificação de nomes de chaves.
