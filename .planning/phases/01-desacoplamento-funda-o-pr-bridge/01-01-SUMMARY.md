# Summary: Plan 01-01 - Desacoplamento de Manifest e Expurgo de Wrappers

## Resultado da Execução

- **Manifest limpo e modernizado (`fxmanifest.lua`):**
  - Removidas dependências legadas: `@ox_lib/init.lua`, `bridge/framework.lua`, `@oxmysql/lib/MySQL.lua`.
  - Definida dependência exclusiva `dependency 'pr_bridge'`.
  - Definido `shared_script '@pr_bridge/init.lua'` como biblioteca universal.
  - Carregamento de scripts organizado em `shared/config.lua`, `client.lua`, `cl_utils.lua`, `sv_db.lua`, `sv_utils.lua`.

- **Expurgo do diretório legado `bridge/`:**
  - Deletado diretório `bridge/` contendo `framework.lua`, `client/client.lua`, `client/common.lua`, `client/raycast.lua`, `server/server.lua` e `server/insert.lua`.
  - Migrada toda a lógica de inicialização de props e sincronização de bancadas para `client.lua` nativo usando `pr_lib.callback`, `pr_lib.target.addLocalEntity` e `pr_lib.target.removeLocalEntity`.

- **Eliminação completa do wrapper `QT`:**
  - Todas as chamadas para `QT.*` foram substituídas por chamadas diretas às APIs nativas de `pr_lib`:
    - `pr_lib.callback.trigger` / `pr_lib.callback.register`
    - `pr_lib.inventory.Items`, `AddItem`, `RemoveItem`, `GetItemCount`
    - `pr_lib.framework.GetPlayer`, `GetPlayerJob`, `GetPlayerGang`, `GetFrameworkJobs`, `GetFrameworkGangs`
    - `pr_lib.notifications.Notify` / `NotifyPlayer`
    - `pr_lib.RegisterContext`, `pr_lib.showContext`, `pr_lib.inputDialog`, `pr_lib.alertDialog`
  - Zero referências a `QT` restam no repositório.

- **Limpeza do `shared/config.lua`:**
  - Removidas flags obsoletas `Config.Framework`, `Config.Target` e `Config.OxProgress`.

## Requisitos Cobertos
- `DEPS-01`: Dependência exclusiva de `pr_bridge` configurada.
- `DEPS-02`: Expurgo de `ox_lib`, `oxmysql` e `ox_target` concluído com 0 referências residuais.
- `DEPS-03`: Camada wrapper `QT` e pasta `bridge/` completamente erradicadas com chamadas diretas a `pr_lib`.
