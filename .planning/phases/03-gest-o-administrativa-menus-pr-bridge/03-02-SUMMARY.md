# Summary: Plan 03-02 - Comandos Nativos de Administração, Permissões ACE e Notificações

## Resultado da Execução

- **Comandos Administrativos Autoritativos com ACE (`sv_utils.lua` e `cl_utils.lua`):**
  - Registro no lado do servidor com checagens de permissão ACE nativas (`isPlayerAdmin`):
    - Console (`source == 0`), `admin`, `crafting`, ou permissões explícitas de comando FiveM (`command.create`, `command.edit`).
    - Disparo de eventos de interface (`forge-crafting:CreateMenu`, `forge-crafting:EditMenu`) apenas para jogadores que satisfaçam a checagem.
    - Bloqueio imediato para jogadores não autorizados com notificação de erro no servidor.
  - Registro seguro no cliente com validação via callback `forge-crafting:PermisionCheck`.
  - Suporte total aos comandos configurados (`Config.CreateTableCommand`, `Config.EditMenuCommand`) e seus aliases com prefixo (`Config.Pfx`).

- **Padronização Centralizada de Notificações:**
  - Todas as notificações no cliente foram unificadas via `notify(title, message, msgType)` consumindo `pr_lib.notifications.Notify`.
  - Todas as notificações no servidor foram unificadas via `serverNotification(source, title, message, msgType)` consumindo `pr_lib.notifications.NotifyPlayer`.

- **Auditoria Completa e Saneamento do Dicionário (`shared/locales.lua`):**
  - Adicionadas todas as chaves que faltavam e geravam valores `nil` no código (`press_edit_item`, `delete_item`, `desc_deleting_item`, `sure_delete_item`, `craft_items_amount`, `craft_time`, `how_many_items`, `item_model`, `item_anim`, `item_level`, `insufficient_permission`, `success_add_item`, etc.).
  - Textos revisados, corrigidos e padronizados em português com descrições informativas e coerentes.

## Requisitos Cobertos
- `ADMIN-03`: Notificações padronizadas via `pr_lib.notifications.Notify` e `NotifyPlayer`, com correção e expansão integral de `shared/locales.lua`.
- `ADMIN-04`: Comandos administrativos e permissões validadas nativamente via ACE no servidor e cliente.
