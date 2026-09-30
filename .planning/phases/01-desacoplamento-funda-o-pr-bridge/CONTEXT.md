# Phase 1: Desacoplamento & Fundação pr_bridge - Context

**Phase:** 1 (Desacoplamento & Fundação pr_bridge)  
**Date:** 2026-09-30  
**Status:** Defined  

## Purpose & Goals

Remover 100% das dependências de bibliotecas externas de terceiros (`ox_lib`, `ox_target`, `oxmysql`) e transformar o **forge-crafting** em um recurso standalone nativo da framework Forge-Core, consumindo diretamente as APIs do `pr_bridge` (`@pr_bridge/init.lua`).

## Scope & User Decisions

1. **Manifest (`fxmanifest.lua`):**
   - Remover `oxmysql` e `ox_lib` de `dependencies {}`.
   - Remover `@ox_lib/init.lua` e `@oxmysql/lib/MySQL.lua`.
   - Adicionar `dependency 'pr_bridge'` e `@pr_bridge/init.lua` em `shared_scripts`.
   - Eliminar carregamento da pasta legada `bridge/`.

2. **Expurgo de Wrappers:**
   - Excluir a pasta legada `bridge/` do forge-crafting (`bridge/framework.lua`, `bridge/client/client.lua`, `bridge/server/server.lua`, etc.).
   - Eliminar a tabela global intermediária `QT`.
   - Fazer chamadas diretas a `pr_lib.db`, `pr_lib.callback`, `pr_lib.inventory`, `pr_lib.framework`, sem funções "wrapper" intermediárias.

3. **Banco de Dados Universal (`pr_lib.db`):**
   - Substituir `MySQL.Sync.execute`, `MySQL.Async.execute`, `MySQL.query` por `pr_lib.db.execute`, `pr_lib.db.query`, `pr_lib.db.single`, `pr_lib.db.insert`.
   - Migrar a criação de tabelas e verificações de colunas para `pr_lib.db.execute` na inicialização do servidor.
   - Ajustar inserção de bancadas (`INSERT INTO forge-crafting`) para aproveitar o `AUTO_INCREMENT` da chave primária `craft_id` em vez de gerar IDs aleatórios via `math.random(1, 1000000)`.

4. **Compatibilidade:**
   - Garantir que as chamadas ao banco funcionem independentemente do driver subjacente (`oxmysql`, `ghmattimysql` ou `mysql-async`), pois o `pr_lib.db` normaliza as chamadas automaticamente.

## Requirements Covered

- `DEPS-01`: Atualizar `fxmanifest.lua` removendo dependências legadas.
- `DEPS-02`: Configurar `pr_bridge` como dependência exclusiva.
- `DEPS-03`: Excluir pasta `bridge/` legada e eliminar o wrapper `QT`.
- `DB-01`: Migrar schemas para `pr_lib.db.execute` / `pr_lib.db.query`.
- `DB-02`: Migrar consultas para `pr_lib.db.query` / `pr_lib.db.single`.
- `DB-03`: Utilizar auto-increment nativo do banco para novas bancadas.
