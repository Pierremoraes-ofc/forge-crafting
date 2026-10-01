# Summary: Plan 03-01 - Menus Administrativos, Contextos e Diálogos com pr_lib

## Resultado da Execução

- **Padronização da Árvore de Menus Administrativos (`cl_utils.lua`):**
  - Implementação completa com `pr_lib.RegisterContext` e `pr_lib.showContext`.
  - Navegação suave com botão de retorno (`menu = parent_id`) em todos os níveis:
    - `crafting_list`: Lista principal de bancadas com metadados (ID, Cargos, Offset).
    - `edit_opcije`: Submenu da bancada com ações de renomear, ajustar altura, reposicionar com Gizmo 3D, gerenciar itens, permissões, blips, teleporte e exclusão.
    - `items_listiii`: Catálogo de receitas cadastradas na bancada selecionada.
    - `edit_options_items`: Painel de edição fina por receita (tempo, ingredientes, quantidade, rótulo, prop, animação, nível e exclusão).
    - `jobs_editss`: Configuração dinâmica de cargos autorizados ou liberação pública da bancada.

- **Cancelamento Suave e Validação com `pr_lib.inputDialog` e `pr_lib.alertDialog`:**
  - Cancelamentos via tecla ESC ou botão Cancelar agora reabrem o menu anterior (`pr_lib.showContext(...)`) sem fechar abruptamente a interface.
  - Confirmações críticas (renomear bancada, excluir bancada, excluir item da bancada) utilizam `pr_lib.alertDialog` com cabeçalho, texto explicativo e botões de confirmação/cancelamento claros.

- **Teleporte Administrativo:**
  - Adicionada opção nativa de teletransporte direto para a bancada selecionada (`teleport_to_coords`) com fade de tela, som imersivo e notificação de confirmação.

## Requisitos Cobertos
- `ADMIN-01`: Menus de administração de bancadas adaptados integralmente para `pr_lib.RegisterContext` e `pr_lib.showContext`.
- `ADMIN-02`: Entradas de dados e confirmações destrutivas migradas para `pr_lib.inputDialog` e `pr_lib.alertDialog`.
