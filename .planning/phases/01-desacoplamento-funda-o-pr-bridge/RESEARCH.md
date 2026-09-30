# Phase 1: Research - Desacoplamento & Fundação pr_bridge

**Analysis Date:** 2026-09-30  
**Phase:** 01-desacoplamento-funda-o-pr-bridge  

## 1. Desacoplamento de Dependências

### Estado Atual em `fxmanifest.lua`
```lua
fx_version 'cerulean'
game 'gta5'
description 'crafting_system'
author 'QT Store'
lua54 'yes'

shared_scripts {
    'shared/*.lua',
    '@ox_lib/init.lua',
    'bridge/framework.lua',
}

client_scripts {
    'bridge/client/*.lua',
    'cl_utils.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server/*.lua',
    'sv_utils.lua',
}

dependencies {
    'oxmysql',
    'ox_lib',
}
```

### Novo Padrão Standalone (`pr_bridge`)
Seguindo o padrão de referência em `pr_scriptTest`:
```lua
fx_version 'cerulean'
game 'gta5'
description 'crafting_system'
lua54 'yes'

dependency 'pr_bridge'

shared_scripts {
    '@pr_bridge/init.lua',
    'shared/config.lua',
    'shared/locales.lua',
    'shared/receita_nova.lua',
    'shared/receita_tuning.lua',
}

client_scripts {
    'cl_utils.lua',
    'client.lua',
}

server_scripts {
    'sv_db.lua',
    'sv_utils.lua',
}
```
- `ox_lib` e `oxmysql` são completamente removidos.
- A pasta `bridge/` legada é removida do manifest.

## 2. API de Banco de Dados (`pr_lib.db`)

No `pr_bridge`, `pr_lib.db` unifica o acesso a dados e detecta automaticamente o driver ativo (`oxmysql`, `ghmattimysql` ou `mysql-async`).

### Equivalência de Funções:
| Operação Legada | Nova API `pr_lib.db` | Exemplo |
|---|---|---|
| `MySQL.Sync.execute` / `MySQL.Async.execute` | `pr_lib.db.execute` | `pr_lib.db.execute(sql, params)` |
| `MySQL.query` / `MySQL.Async.fetchAll` | `pr_lib.db.query` | `local rows = pr_lib.db.query("SELECT * FROM ... WHERE craft_id = ?", { id })` |
| `MySQL.Async.fetchAll(...)[1]` | `pr_lib.db.single` | `local row = pr_lib.db.single("SELECT * FROM ... WHERE craft_name = ?", { name })` |
| `MySQL.Async.execute("INSERT ...")` | `pr_lib.db.insert` | `local insertId = pr_lib.db.insert("INSERT ...", params)` |

### Normalização do Schema e Auto-Increment
- O schema da tabela `forge-crafting` já possui `craft_id int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY`.
- Na implementação legada, `math.random(1, 1000000)` era gerado no Lua e inserido manualmente, correndo risco de colisão.
- Com `pr_lib.db.insert`, omitimos `craft_id` do INSERT e recebemos o ID gerado pelo motor MySQL.

## 3. Eliminação do Wrapper `QT`

A implementação legada continha uma tabela global `QT` em `bridge/client/client.lua` e `bridge/server/server.lua` que duplicava chamadas para ESX e QBCore:
```lua
-- ANTIGO (LEGADO / WRAPPER DESNECESSÁRIO)
QT.AddItem(source, item, count)
QT.GetJobs()
QT.TriggerCallback(...)
```
A diretriz do projeto é: **chamadas diretas a `pr_lib.*` sem wrappers**.
```lua
-- NOVO (DIRETO VIA pr_bridge)
pr_lib.inventory.AddItem(source, item, count)
pr_lib.framework.GetFrameworkJobs()
pr_lib.callback.await(name, ...)
pr_lib.callback.register(name, function(source, ...) ... end)
```

## 4. Riscos e Mitigações

1. **Risco:** Referências órfãs a `QT.*` ou `ox_lib` quebrando na inicialização.
   - **Mitigação:** Varredura completa com `grep_search` para garantir que nenhum arquivo do recurso invoque `QT`, `lib.` ou `exports.ox_` durante a Fase 1.
2. **Risco:** Falha de carregamento se `pr_bridge` não estiver iniciado.
   - **Mitigação:** `dependency 'pr_bridge'` no manifest e guarda nativa no `@pr_bridge/init.lua` garantem ordem de inicialização correta no FXServer.
