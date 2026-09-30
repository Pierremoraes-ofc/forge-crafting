# Summary: Plan 01-02 - Migração de Banco de Dados para pr_lib.db

## Resultado da Execução

- **Criação de `sv_db.lua`:**
  - Gerenciamento unificado e automático do banco de dados na inicialização do recurso (`onResourceStart`).
  - Criação automática das tabelas com tratamento correto de sintaxe e nomes com hífen:
    - ``CREATE TABLE IF NOT EXISTS `forge-crafting` (craft_id INT AUTO_INCREMENT PRIMARY KEY, ...)``
    - ``CREATE TABLE IF NOT EXISTS `forge-crafting-items` (id INT AUTO_INCREMENT PRIMARY KEY, ...)``
  - Verificação e adição automática de colunas caso inexistentes (`model`, `anim`, `level`) via `pr_lib.db.query` e `pr_lib.db.execute`.

- **Refatoração integral de queries em `sv_utils.lua`:**
  - Removido qualquer uso de `MySQL.Async`, `MySQL.Sync` e `MySQL.query`.
  - Migradas todas as operações para `pr_lib.db`:
    - `pr_lib.db.single`: Para verificação de existência de tabela (`forge-crafting:TableExist`).
    - `pr_lib.db.query`: Para carregamento de bancadas (`forge-crafting:GetList`), itens da bancada (`forge-crafting:GetListItems`, `forge-crafting:fetchItemsFromId`, `forge-crafting:fetchTables`).
    - `pr_lib.db.insert`: Para criação de novas bancadas (`forge-crafting:CreateWorkShop`), removendo `math.random` e delegando ao `AUTO_INCREMENT` do MySQL.
    - `pr_lib.db.execute`: Para deleções, atualizações de nome, animações, cargos e níveis.
  - Todas as consultas utilizam placeholders parametrizados `?` garantindo proteção contra SQL injection e compatibilidade agnóstica com qualquer driver suportado pelo `pr_bridge` (oxmysql, ghmattimysql, mysql-async).

## Requisitos Cobertos
- `DB-01`: Migração de todas as operações de banco de dados para `pr_lib.db` concluída.
- `DB-02`: Suporte a driver de banco universal agnóstico ativado via `pr_bridge`.
- `DB-03`: `craft_id` agora utiliza `AUTO_INCREMENT` nativo do banco de dados para criação de bancadas.
