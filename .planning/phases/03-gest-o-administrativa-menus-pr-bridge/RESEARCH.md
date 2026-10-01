# Pesquisa Técnica: Fase 3 - Gestão Administrativa & Menus pr_bridge

## 1. Padrões de Contexto do `pr_bridge` (`pr_lib.RegisterContext` / `showContext`)

Conforme documentado no `pr_bridge`, os menus de contexto seguem a seguinte estrutura de dados:

```lua
pr_lib.RegisterContext({
    id = 'crafting_admin_main',
    title = 'Painel de Crafting',
    menu = 'parent_menu_id', -- Opcional: define o menu para o botão de voltar
    canClose = true,
    options = {
        {
            title = 'Nova Bancada',
            description = 'Posiciona e cria uma nova bancada de trabalho',
            icon = 'fa-solid fa-plus',
            arrow = true,
            onSelect = function()
                -- Ação
            end
        },
        {
            title = 'Bancada X',
            description = 'ID: 1 | Cargos: Mecânico',
            icon = 'fa-solid fa-screwdriver-wrench',
            metadata = {
                { label = 'ID', value = 1 },
                { label = 'Prop', value = 'gr_prop_gr_bench_02a' }
            },
            arrow = true,
            onSelect = function()
                -- Abre submenu de edição
            end
        }
    }
})

pr_lib.showContext('crafting_admin_main')
```

---

## 2. Padrões de Input Dialog e Alert Dialog (`pr_lib.inputDialog` / `alertDialog`)

### Input Dialog
```lua
local input = pr_lib.inputDialog('Configurar Bancada', {
    { type = 'input', label = 'Nome', required = true, icon = 'signature' },
    { type = 'input', label = 'Modelo', default = 'gr_prop_gr_bench_02a', required = true },
    { type = 'checkbox', label = 'Restringir por Job/Gangue', checked = false },
    { type = 'checkbox', label = 'Ativar Blip no Mapa', checked = false },
})
if not input then return end -- Usuário cancelou ou fechou com ESC
```

### Alert Dialog
```lua
local alert = pr_lib.alertDialog({
    header = 'Confirmação',
    content = 'Tem certeza que deseja excluir esta bancada permanentemente?',
    centered = true,
    cancel = true
})

if alert == 'confirm' then
    -- Executa exclusão
end
```

---

## 3. Padrões de Notificação do `pr_bridge`

- **Client-side:**
```lua
pr_lib.notifications.Notify({
    title = "Crafting",
    description = "Mensagem",
    type = "success" -- "inform", "error", "warning"
})
```

- **Server-side:**
```lua
pr_lib.notifications.NotifyPlayer(source, {
    title = "Crafting",
    description = "Mensagem",
    type = "error"
})
```

---

## 4. Padrões de Comandos e Permissões ACE

No servidor:
```lua
RegisterCommand('crafting_admin', function(source, args)
    if source == 0 or IsPlayerAceAllowed(source, 'admin') or IsPlayerAceAllowed(source, 'crafting') then
        TriggerClientEvent('forge-crafting:EditMenu', source)
    else
        pr_lib.notifications.NotifyPlayer(source, {
            title = locales.main_title or "Crafting",
            description = locales.insufficient_permission or "Você não tem permissão para este comando.",
            type = "error"
        })
    end
end, false)
```
Isso garante bloqueio imediato no servidor para qualquer jogador não autorizado antes mesmo de abrir qualquer interface ou callback.
