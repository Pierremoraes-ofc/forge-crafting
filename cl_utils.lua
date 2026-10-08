-- Client utility and administration menu via pr_bridge

local function notify(title, message, msgType)
    if pr_lib.notifications and pr_lib.notifications.Notify then
        pr_lib.notifications.Notify({
            title = title or locales.main_title,
            description = message,
            type = msgType or "inform"
        })
    end
end

local function registerCraftingCommand(command, event)
    if not command or command == '' then return end

    RegisterCommand(command, function()
        pr_lib.callback.trigger('forge-crafting:PermisionCheck', function(hasPerm)
            if hasPerm then
                TriggerEvent(event)
            end
        end)
    end, false)
end

registerCraftingCommand(Config.CreateTableCommand, "forge-crafting:CreateMenu")
registerCraftingCommand(Config.EditMenuCommand, "forge-crafting:EditMenu")
registerCraftingCommand("benchmodels", "forge-crafting:BenchModelsMenu")
registerCraftingCommand("receitas", "forge-crafting:RecipeCatalogMenu")
registerCraftingCommand("recipecatalog", "forge-crafting:RecipeCatalogMenu")

if Config.Pfx and Config.Pfx ~= '' then
    registerCraftingCommand(Config.Pfx .. Config.CreateTableCommand, "forge-crafting:CreateMenu")
    registerCraftingCommand(Config.Pfx .. Config.EditMenuCommand, "forge-crafting:EditMenu")
    registerCraftingCommand(Config.Pfx .. "benchmodels", "forge-crafting:BenchModelsMenu")
    registerCraftingCommand(Config.Pfx .. "receitas", "forge-crafting:RecipeCatalogMenu")
    registerCraftingCommand(Config.Pfx .. "recipecatalog", "forge-crafting:RecipeCatalogMenu")
end

AddEventHandler('forge-crafting:EditMenu', function()
    pr_lib.callback.trigger('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then return end
        pr_lib.callback.trigger('forge-crafting:GetList', function(data)
            local options = {}
            -- Criar uma nova mesa de crafting
            options[#options + 1] = {
                title = locales.new_crafting_table,
                icon = 'plus',
                event = 'forge-crafting:CreateMenu',
                description = locales.desc_new_crafting_table,
                arrow = true
            }

            -- Gerenciar Modelos de Bancadas
            options[#options + 1] = {
                title = locales.manage_bench_models or "Gerenciar Modelos de Bancadas",
                icon = 'cube',
                event = 'forge-crafting:BenchModelsMenu',
                description = locales.desc_manage_bench_models or "Cadastre ou personalize modelos 3D, offsets da DUI, animações e câmera.",
                arrow = true
            }

            -- Construtor e Calibrador de Bancada DUI
            options[#options + 1] = {
                title = "Construtor e Calibrador de Bancada DUI",
                icon = "drafting-compass",
                onSelect = function()
                    ExecuteCommand("createbench")
                end,
                description = "Spawna prop (ex: gr_prop_gr_bench_02a), calibra coordenadas da DUI no prop com Builder 3D e salva.",
                arrow = true
            }

            -- Personalizar Cores e Visual da Bancada (DUI e Standby)
            options[#options + 1] = {
                title = "Personalizar Cores e Visual da Bancada",
                icon = "palette",
                description = "Configure fundos (ou transparente), imagens de fundo, contornos, efeito neon e cores da interface.",
                arrow = true,
                onSelect = function()
                    OpenThemeCustomizationMenu()
                end
            }

            -- Catálogo Global de Receitas
            options[#options + 1] = {
                title = "Catálogo Global de Receitas",
                icon = "book-open",
                description = "Biblioteca de receitas: cadastre novas receitas, edite ou importe predefinições.",
                arrow = true,
                event = "forge-crafting:RecipeCatalogMenu"
            }

            if data then
                for i = 1, #data do
                    local dat = data[i]
                    options[#options + 1] = {
                        title = dat.craft_name,
                        icon = 'wrench',
                        event = 'forge-crafting:OpenEditFunctions',
                        description = (dat.model_slug and ("Modelo: " .. dat.model_slug .. " | ") or "") .. locales.listdescription,
                        arrow = true,
                        args = {
                            craft_name = dat.craft_name,
                            craft_id = dat.craft_id,
                            jobs = dat.jobs,
                            offset = dat.offset,
                            targetable = dat.targetable,
                            model_slug = dat.model_slug
                        }
                    }
                end
            end

            pr_lib.RegisterContext({
                id = 'crafting_list',
                menu = 'menu_crafting',
                title = locales.list,
                options = options
            })
            pr_lib.showContext('crafting_list')
        end)
    end)
end)

local function openJobConfigurationDialog(cb)
    pr_lib.callback.trigger('forge-crafting:fetchFrameworkAuthList', function(authData)
        authData = authData or {}
        local jobOptions = authData.jobs or {}
        local gangOptions = authData.gangs or {}

        if #jobOptions == 0 and #gangOptions == 0 then
            pr_lib.callback.trigger('forge-crafting:fetchJobs', function(legacyJobs)
                for _, j in pairs(legacyJobs or {}) do
                    jobOptions[#jobOptions + 1] = { label = j.label, value = j.value, name = j.value, default_label = j.label }
                end
            end)
        end

        local step1 = pr_lib.inputDialog("Restrição de Bancada", {
            {
                type = 'select',
                label = "Tipo de Organização",
                description = "Defina se o acesso é restrito a um Emprego ou Facção",
                options = {
                    { label = "💼 Emprego (Job)", value = "job" },
                    { label = "💀 Facção / Gangue (Gang)", value = "gang" },
                },
                default = "job",
                required = true,
                icon = "briefcase"
            }
        })

        if not step1 or not step1[1] then
            if cb then cb(nil) end
            return
        end

        local authType = step1[1]

        if authType == "job" then
            if #jobOptions == 0 then
                notify(locales.main_title or "Crafting", "Nenhum emprego encontrado na framework!", "error")
                if cb then cb(nil) end
                return
            end

            local step2 = pr_lib.inputDialog("Configurar Restrição de Emprego", {
                {
                    type = 'select',
                    label = "Emprego Autorizado",
                    description = "Selecione qual emprego poderá usar esta bancada",
                    options = jobOptions,
                    required = true,
                    searchable = true,
                    icon = "id-badge"
                },
                {
                    type = 'checkbox',
                    label = "Exigir Serviço Ativo (On-Duty obrigatório)",
                    checked = true
                },
                {
                    type = 'number',
                    label = "Cargo / Nível Mínimo do Emprego",
                    description = "Nível mínimo do cargo exigido (0 = qualquer cargo/recruta)",
                    default = 0,
                    min = 0,
                    max = 99,
                    required = true,
                    icon = "ranking-star"
                }
            })

            if not step2 or not step2[1] then
                if cb then cb(nil) end
                return
            end

            local chosenName = step2[1]
            local chosenLabel = chosenName
            for _, opt in ipairs(jobOptions) do
                if opt.value == chosenName then
                    chosenLabel = opt.default_label or opt.label or chosenName
                    break
                end
            end

            local resultJob = {
                auth_type = 'job',
                name = chosenName,
                label = chosenLabel,
                require_duty = (step2[2] == true),
                min_grade = tonumber(step2[3]) or 0,
                value = chosenName
            }

            if cb then cb(resultJob) end
        else
            if #gangOptions == 0 then
                notify(locales.main_title or "Crafting", "Nenhuma facção/gangue encontrada na framework!", "error")
                if cb then cb(nil) end
                return
            end

            local step2 = pr_lib.inputDialog("Configurar Restrição de Facção / Gangue", {
                {
                    type = 'select',
                    label = "Facção / Gangue Autorizada",
                    description = "Selecione qual facção poderá usar esta bancada",
                    options = gangOptions,
                    required = true,
                    searchable = true,
                    icon = "skull"
                },
                {
                    type = 'number',
                    label = "Cargo / Nível Mínimo na Facção",
                    description = "Nível mínimo do cargo exigido (0 = qualquer cargo)",
                    default = 0,
                    min = 0,
                    max = 99,
                    required = true,
                    icon = "ranking-star"
                }
            })

            if not step2 or not step2[1] then
                if cb then cb(nil) end
                return
            end

            local chosenName = step2[1]
            local chosenLabel = chosenName
            for _, opt in ipairs(gangOptions) do
                if opt.value == chosenName then
                    chosenLabel = opt.default_label or opt.label or chosenName
                    break
                end
            end

            local resultGang = {
                auth_type = 'gang',
                name = chosenName,
                label = chosenLabel,
                require_duty = false,
                min_grade = tonumber(step2[2]) or 0,
                value = chosenName
            }

            if cb then cb(resultGang) end
        end
    end)
end

AddEventHandler('forge-crafting:OpenEditFunctions', function(args)
    pr_lib.callback.trigger('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then return end
        pr_lib.RegisterContext({
            id = 'edit_opcije',
            title = args.craft_name,
            menu = "crafting_list",
            options = {
                {
                    title = locales.change_name,
                    icon = "edit",
                    metadata = {
                        { label = locales.current_name, value = args.craft_name },
                    },
                    onSelect = function()
                        local input = pr_lib.inputDialog(args.craft_name, {
                            { type = 'input', label = locales.new_name, placeholder = locales.desc_new_name, required = true, icon = "signature" },
                        })
                        if not input then return pr_lib.showContext('edit_opcije') end
                        local warning = pr_lib.alertDialog({
                            header = locales.automaticmessage,
                            content = locales.sure_question .. args.craft_name .. locales.to_question .. input[1] .. "?",
                            centered = true,
                            cancel = true
                        })
                        if warning == "confirm" then
                            TriggerServerEvent("forge-crafting:ChangeName", args.craft_id, input[1])
                            notify(locales.main_title,
                                locales.changedname .. args.craft_name .. locales.to_question .. input[1],
                                "success")
                            Wait(100)
                            TriggerServerEvent("forge-crafting:Update")
                            TriggerEvent('forge-crafting:EditMenu')
                        else
                            pr_lib.showContext('edit_opcije')
                            notify(locales.main_title, locales.canceled_namechanging, "inform")
                        end
                    end,
                },
                {
                    title = locales.change_height,
                    icon = "fa-solid fa-arrows-up-down",
                    metadata = {
                        { label = locales.current_offset or "Offset Atual", value = args.offset },
                    },
                    onSelect = function()
                        local input = pr_lib.inputDialog(locales.change_height, {
                            { type = 'number', label = locales.new_height, default = args.offset, required = true, min = -10.0, max = 10.0, precision = 2, step = 0.01 },
                        })
                        if not input then return pr_lib.showContext('edit_opcije') end
                        TriggerServerEvent("forge-crafting:UpdateHeight", input[1], args.craft_id)
                        Wait(100)
                        TriggerEvent('forge-crafting:EditMenu')
                    end,
                },
                {
                    title = locales.add_items_craft,
                    icon = "wrench",
                    description = locales.desc_add,
                    onSelect = function()
                        local options = {
                            {
                                title = locales.add_new_item,
                                icon = "plus",
                                onSelect = function()
                                    pr_lib.callback.trigger('forge-crafting:GetListItems', function(result)
                                        local adder = pr_lib.inputDialog(args.craft_name, {
                                            { type = 'select', label = locales.item, description = locales.desc_add_1, options = GetBaseItems(), required = true, searchable = true },
                                            { type = 'input', label = locales.item_label, description = locales.desc_add_2, required = true },
                                            { type = 'number', label = locales.craft_items_amount, description = locales.desc_add_3, required = true, min = 1 },
                                            { type = 'number', label = locales.craft_time, description = locales.desc_add_4, required = true, min = 1 },
                                            { type = 'number', label = locales.how_many_items, description = locales.desc_add_5, required = true, min = 1 },
                                            { type = 'input', label = locales.item_model, description = locales.desc_add_6, required = false },
                                            { type = 'input', label = locales.item_anim, description = locales.desc_add_7, required = false },
                                            { type = 'number', label = locales.item_level, description = locales.desc_add_8, required = false },
                                            { type = 'number', label = "XP concedido", description = "Quantidade de experiência concedida ao fabricar este item", required = false, default = 10, min = 0 },
                                        })
                                        if not adder then return TriggerEvent('forge-crafting:OpenEditFunctions', args) end
                                        local recipeTable = createRecipe(adder[5])
                                        if not recipeTable then return TriggerEvent('forge-crafting:OpenEditFunctions', args) end
                                        local data = {
                                            craft_id = args.craft_id,
                                            main_item = adder[1],
                                            item_label = adder[2],
                                            amount = adder[3],
                                            time = adder[4],
                                            recipe = recipeTable,
                                            model = adder[6] and adder[6] ~= "" and adder[6] or nil,
                                            anim = adder[7] and adder[7] ~= "" and adder[7] or nil,
                                            level = adder[8] and tonumber(adder[8]) or nil,
                                            xp = adder[9] and tonumber(adder[9]) or 10
                                        }
                                        TriggerServerEvent("forge-crafting:AddItemCrafting", data)
                                        notify(locales.main_title, locales.success_add_item, "success")
                                        Wait(100)
                                        TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                    end, args.craft_id)
                                end,
                            },
                            {
                                title = "Vincular do Catálogo de Receitas",
                                icon = "layer-group",
                                description = "Selecione receitas do catálogo global para adicionar a esta bancada",
                                onSelect = function()
                                    pr_lib.callback.trigger('forge-crafting:getRecipeCatalog', function(catalog)
                                        if not catalog or #catalog == 0 then
                                            notify(locales.main_title or "Crafting", "Nenhuma receita encontrada no catálogo global. Use o menu de catálogo para cadastrar ou importar receitas.", "error")
                                            return TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                        end

                                        local selectOptions = {}
                                        for _, rec in ipairs(catalog) do
                                            local catTag = rec.category and string.format("[%s] ", rec.category) or ""
                                            selectOptions[#selectOptions + 1] = {
                                                value = rec.item,
                                                label = string.format("%s%s (%s)", catTag, rec.item_label or rec.item, rec.item)
                                            }
                                        end

                                        local linkInput = pr_lib.inputDialog("Vincular Receitas à Bancada", {
                                            {
                                                type = 'select',
                                                label = "Selecione as Receitas",
                                                description = "Clique nas receitas para adicioná-las como tags",
                                                options = selectOptions,
                                                multiple = true,
                                                searchable = true,
                                                clearable = true,
                                                required = true,
                                                icon = "tags"
                                            }
                                        })

                                        if not linkInput or not linkInput[1] or #linkInput[1] == 0 then
                                            return TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                        end

                                        local selectedItems = linkInput[1]
                                        pr_lib.callback.trigger('forge-crafting:linkRecipesToBench', function(success, added, updated)
                                            if success then
                                                Wait(150)
                                                TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                            else
                                                notify(locales.main_title or "Crafting", added or "Falha ao vincular receitas.", "error")
                                                TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                            end
                                        end, args.craft_id, selectedItems)
                                    end)
                                end,
                            }
                        }

                        pr_lib.callback.trigger('forge-crafting:GetListItems', function(result)
                            if result and type(result) == "table" then
                                for i = 1, #result do
                                    local someData = result[i]
                                    options[#options + 1] = {
                                        title = someData.item_label,
                                        description = locales.press_edit_item,
                                        icon = "cube",
                                        arrow = true,
                                        onSelect = function()
                                            pr_lib.RegisterContext({
                                                id = 'edit_options_items',
                                                menu = 'items_listiii',
                                                title = someData.item_label,
                                                options = {
                                                    {
                                                        title = locales.delete_item,
                                                        icon = "trash",
                                                        description = locales.desc_deleting_item,
                                                        onSelect = function()
                                                            local warning = pr_lib.alertDialog({
                                                                header = locales.automaticmessage,
                                                                content = locales.sure_delete_item .. someData.item_label .. "?",
                                                                centered = true,
                                                                cancel = true
                                                            })
                                                            if warning == "confirm" then
                                                                TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, nil, "delete")
                                                                Wait(100)
                                                                TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                            else
                                                                pr_lib.showContext('edit_options_items')
                                                            end
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_time,
                                                        icon = "clock",
                                                        description = locales.desc_change_time,
                                                        onSelect = function()
                                                            local timer = pr_lib.inputDialog(locales.new_time, {
                                                                { type = 'number', label = locales.new_time_input, default = someData.time, required = true, min = 1 },
                                                            })
                                                            if not timer then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, timer[1], "time")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_recipe,
                                                        icon = "scroll",
                                                        description = locales.desc_change_recipe,
                                                        onSelect = function()
                                                            local updatera = pr_lib.inputDialog(args.craft_name, {
                                                                { type = 'number', label = locales.how_many_items, description = locales.desc_add_5, required = true, min = 1 },
                                                            })
                                                            if not updatera then return pr_lib.showContext('edit_options_items') end
                                                            local recipeTable = createRecipe(updatera[1])
                                                            if not recipeTable then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, recipeTable, "recipe")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_label,
                                                        icon = "signature",
                                                        description = locales.desc_change_label,
                                                        onSelect = function()
                                                            local name = pr_lib.inputDialog(args.craft_name, {
                                                                { type = 'input', label = locales.item_label, default = someData.item_label, required = true },
                                                            })
                                                            if not name then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, name[1], "label")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_amount,
                                                        icon = "plus-minus",
                                                        description = locales.desc_change_amount,
                                                        onSelect = function()
                                                            local amount = pr_lib.inputDialog(args.craft_name, {
                                                                { type = 'number', label = locales.item_amount, default = someData.amount, required = true, min = 1 },
                                                            })
                                                            if not amount then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, amount[1], "amount")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_model,
                                                        icon = "box",
                                                        description = locales.desc_change_model,
                                                        onSelect = function()
                                                            local model = pr_lib.inputDialog(args.craft_name, {
                                                                { type = 'input', label = locales.item_model, default = someData.model or "", required = false },
                                                            })
                                                            if not model then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, model[1], "model")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_anim,
                                                        icon = "person-walking",
                                                        description = locales.desc_change_anim,
                                                        onSelect = function()
                                                            local anim = pr_lib.inputDialog(args.craft_name, {
                                                                { type = 'input', label = locales.item_anim, default = someData.anim or "", required = false },
                                                            })
                                                            if not anim then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, anim[1], "anim")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_level,
                                                        icon = "star",
                                                        description = locales.desc_change_level,
                                                        onSelect = function()
                                                            local level = pr_lib.inputDialog(args.craft_name, {
                                                                { type = 'number', label = locales.item_level, default = someData.level or 0, required = false },
                                                            })
                                                            if not level then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, level[1], "level")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    },
                                                    {
                                                        title = "Alterar XP Concedido",
                                                        icon = "award",
                                                        description = "Modificar a quantidade de experiência concedida ao fabricar este item.",
                                                        onSelect = function()
                                                            local xpDialog = pr_lib.inputDialog(args.craft_name, {
                                                                { type = 'number', label = "XP ao Fabricar", default = someData.xp or 10, required = true, min = 0 },
                                                            })
                                                            if not xpDialog then return pr_lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, xpDialog[1], "xp")
                                                            Wait(100)
                                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                                        end,
                                                    }
                                                }
                                            })
                                            pr_lib.showContext('edit_options_items')
                                        end,
                                    }
                                end
                            end

                            pr_lib.RegisterContext({
                                id = 'items_listiii',
                                menu = 'edit_opcije',
                                title = locales.list_itemsa,
                                options = options
                            })
                            pr_lib.showContext('items_listiii')
                        end, args.craft_id)
                    end,
                },
                {
                    title = locales.job_options,
                    icon = "briefcase",
                    description = locales.desc_job_options,
                    onSelect = function()
                        pr_lib.callback.trigger('forge-crafting:CheckOptionsEnable', function(isPublic)
                            local jobOptions = {}

                            jobOptions[#jobOptions + 1] = {
                                title = isPublic and locales.enable_jobs or locales.add_jobs,
                                icon = "unlock",
                                description = locales.desc_enable_jobs,
                                onSelect = function()
                                    openJobConfigurationDialog(function(configuredJob)
                                        if not configuredJob then return pr_lib.showContext('jobs_editss') end
                                        TriggerServerEvent("forge-crafting:ChangeJobs", args.craft_id, configuredJob)
                                        Wait(100)
                                        TriggerEvent('forge-crafting:EditMenu')
                                    end)
                                end,
                            }

                            if not isPublic then
                                jobOptions[#jobOptions + 1] = {
                                    title = locales.disable_jobs,
                                    icon = "lock-open",
                                    description = locales.desc_disable_jobs,
                                    onSelect = function()
                                        TriggerServerEvent("forge-crafting:RemoveRequirement", args.craft_id)
                                        Wait(100)
                                        TriggerEvent('forge-crafting:EditMenu')
                                    end,
                                }
                            end

                            pr_lib.RegisterContext({
                                id = 'jobs_editss',
                                menu = 'edit_opcije',
                                title = locales.job_options,
                                options = jobOptions
                            })
                            pr_lib.showContext('jobs_editss')
                        end, args.craft_id)
                    end,
                },
                {
                    title = locales.change_coords,
                    icon = "location-dot",
                    description = locales.desc_change_coords,
                    onSelect = function()
                        pr_lib.callback.trigger("forge-crafting:GetEntityModel", function(model)
                            updateModelPosition(model, args)
                        end, args.craft_id)
                    end,
                },
                {
                    title = locales.blip_setup,
                    icon = "map-pin",
                    description = locales.desc_blip_setup,
                    onSelect = function()
                        pr_lib.callback.trigger("forge-crafting:GetEntityCoords", function(coords)
                            local blip = pr_lib.inputDialog(locales.blip_creation, {
                                { type = 'number', label = locales.blip_sprite, required = true, max = 883, min = 0 },
                                { type = 'number', label = locales.blip_colour, required = true, max = 85, min = 0 },
                                { type = 'input', label = locales.blip_scale, required = true, default = "0.7" },
                                { type = 'input', label = locales.blip_label, required = true, default = args.craft_name, icon = "signature" },
                            })
                            if not blip then return pr_lib.showContext('edit_opcije') end
                            local blip_data = { sprite = blip[1], colour = blip[2], scale = tonumber(blip[3]) or 0.7, blip_label = blip[4] }
                            TriggerServerEvent("forge-crafting:UpdateBlip", blip_data, args.craft_id, args.craft_name)
                            Wait(100)
                            TriggerEvent('forge-crafting:EditMenu')
                        end, args.craft_id)
                    end,
                },
                {
                    title = locales.teleport_to_coords,
                    icon = "fa-solid fa-person-walking-dashed-line-arrow-right",
                    description = locales.desc_teleport or "Teleporta até as coordenadas da bancada.",
                    onSelect = function()
                        pr_lib.callback.trigger("forge-crafting:GetEntityCoords", function(coords)
                            if coords then
                                local ped = PlayerPedId()
                                DoScreenFadeOut(250)
                                Wait(300)
                                SetEntityCoords(ped, coords.x, coords.y, coords.z + 0.2, false, false, false, false)
                                SetEntityHeading(ped, coords.w or 0.0)
                                Wait(200)
                                DoScreenFadeIn(250)
                                PlaySoundFrontend(-1, "Zoom_In", "DLC_HEIST_PLANNING_BOARD_SOUNDS", 1)
                                notify(locales.main_title, (locales.teleport_success or "Teleportado para: ") .. args.craft_name, "success")
                            else
                                notify(locales.main_title, "Coordenadas da bancada não encontradas.", "error")
                            end
                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                        end, args.craft_id)
                    end,
                },
                {
                    title = locales.change_bench_model or "Alterar Modelo da Bancada",
                    icon = "cube",
                    description = locales.desc_change_bench_model or "Troca o modelo 3D, animações e offsets atribuídos a esta bancada.",
                    metadata = {
                        { label = "Modelo Atual", value = args.model_slug or "default" }
                    },
                    onSelect = function()
                        pr_lib.callback.trigger('forge-crafting:getBenchModels', function(models)
                            if not models or #models == 0 then
                                return notify(locales.main_title, "Nenhum modelo cadastrado.", "error")
                            end
                            local modelOptions = {}
                            for _, m in ipairs(models) do
                                modelOptions[#modelOptions + 1] = {
                                    title = m.label or m.slug,
                                    description = string.format("Prop: %s | Slug: %s", m.model, m.slug),
                                    icon = "cube",
                                    onSelect = function()
                                        TriggerServerEvent("forge-crafting:UpdateBenchModel", args.craft_id, m.slug)
                                        args.model_slug = m.slug
                                        Wait(150)
                                        TriggerEvent('forge-crafting:EditMenu')
                                    end
                                }
                            end
                            pr_lib.RegisterContext({
                                id = 'select_bench_model_edit',
                                title = locales.change_bench_model or "Alterar Modelo da Bancada",
                                menu = 'edit_opcije',
                                options = modelOptions
                            })
                            pr_lib.showContext('select_bench_model_edit')
                        end)
                    end
                },
                {
                    title = locales.delete_crafttable,
                    icon = "trash",
                    description = locales.desc_deleting,
                    onSelect = function()
                        local warning = pr_lib.alertDialog({
                            header = locales.automaticmessage,
                            content = locales.sure_delete .. args.craft_name .. "?",
                            centered = true,
                            cancel = true
                        })
                        if warning == "confirm" then
                            TriggerServerEvent("forge-crafting:DeleteTable", args.craft_id, args.craft_name)
                            notify(locales.main_title, locales.sucessfullydeleted .. " " .. args.craft_name, "success")
                            Wait(100)
                            TriggerServerEvent("forge-crafting:Update")
                            TriggerEvent('forge-crafting:EditMenu')
                        else
                            pr_lib.showContext('edit_opcije')
                            notify(locales.main_title, locales.deleting_cancelation, "inform")
                        end
                    end,
                },
            }
        })

        pr_lib.showContext('edit_opcije')
    end)
end)

local function placeBenchWithGizmo(modelName, initialCoords, initialHeading, title, cb)
    local gizmoApi = (pr_lib.fivem and pr_lib.fivem.gizmo) or pr_lib.gizmo
    if not gizmoApi or not gizmoApi.await then
        notify(locales.main_title or "Crafting", "Modulo de Gizmo 3D do pr_bridge indisponivel.", "error")
        if cb then cb(nil, nil, false) end
        return
    end

    local modelHash = type(modelName) == "string" and joaat(modelName) or modelName
    local loaded = false
    local streaming = pr_lib.fivem and pr_lib.fivem.streaming
    if streaming and streaming.requestModel then
        loaded, modelHash = streaming.requestModel(modelHash, 3000)
    else
        RequestModel(modelHash)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
            Wait(10)
        end
        loaded = HasModelLoaded(modelHash)
    end

    if not loaded then
        notify(locales.main_title or "Crafting", "Falha ao carregar modelo do prop para o gizmo.", "error")
        if cb then cb(nil, nil, false) end
        return
    end

    local ped = PlayerPedId()
    local spawnCoords
    if initialCoords and (initialCoords.x or initialCoords[1]) then
        spawnCoords = vector3(initialCoords.x or initialCoords[1], initialCoords.y or initialCoords[2], initialCoords.z or initialCoords[3])
    else
        spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    end

    local spawnHeading = initialHeading or GetEntityHeading(ped)
    local obj = CreateObjectNoOffset(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, true, false)
    if streaming and streaming.releaseModel then
        streaming.releaseModel(modelHash)
    else
        SetModelAsNoLongerNeeded(modelHash)
    end

    if not obj or obj == 0 or not DoesEntityExist(obj) then
        notify(locales.main_title or "Crafting", "Falha ao instanciar prop para posicionamento.", "error")
        if cb then cb(nil, nil, false) end
        return
    end

    SetEntityHeading(obj, spawnHeading)
    SetEntityAsMissionEntity(obj, true, true)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)

    local confirmedResult, finalResult = gizmoApi.await(obj, {
        title = title or "Posicionar Bancada (TAB para modo de precisao)",
        offset = vector3(0.0, 0.0, 0.0),
        precisionMode = false,
        precisionSpeed = 1.0,
        allowFreeCameraToggle = true,
        restoreOnCancel = true,
        ui = true,
        onUpdate = function()
            return true
        end,
    })

    local result = confirmedResult or finalResult or { confirmed = false, reason = "cancelado" }
    local finalCoords = result.coords or GetEntityCoords(obj)
    local finalRotation = result.rotation or GetEntityRotation(obj, 2)
    local finalHeading = finalRotation and finalRotation.z or GetEntityHeading(obj)

    if DoesEntityExist(obj) then
        DeleteObject(obj)
    end

    if result.confirmed then
        notify(locales.main_title or "Crafting", "Posicao confirmada pelo Gizmo.", "success")
        if cb then cb(finalCoords, finalHeading, true) end
    else
        notify(locales.main_title or "Crafting", "Posicionamento cancelado.", "inform")
        if cb then cb(nil, nil, false) end
    end
end

function updateModelPosition(model, args)
    pr_lib.callback.trigger("forge-crafting:GetEntityCoords", function(coords)
        local initialCoords = coords or GetEntityCoords(PlayerPedId())
        local initialHeading = (coords and coords.w) or 0.0

        placeBenchWithGizmo(model, initialCoords, initialHeading, "Editar Posicao: " .. (args.craft_name or ""), function(newCoords, newHeading, confirmed)
            if confirmed and newCoords then
                local new_position = vector4(newCoords.x, newCoords.y, newCoords.z, newHeading)
                TriggerServerEvent("forge-crafting:UpdatePosition", new_position, args.craft_id, args.craft_name)
                Wait(100)
                TriggerServerEvent("forge-crafting:Update")
            end
            TriggerEvent('forge-crafting:OpenEditFunctions', args)
        end)
    end, args.craft_id)
end

function createRecipe(numRecipe)
    local recipetable = {}
    for i = 1, numRecipe do
        local recipeInput = pr_lib.inputDialog(locales.recipeitem .. ' (' .. i .. '/' .. numRecipe .. ')', {
            { type = 'select', label = locales.item, description = locales.desc_add_1, options = GetBaseItems(), required = true, searchable = true },
            { type = 'input', label = locales.item_label, description = locales.desc_add_2, required = true },
            { type = 'number', label = locales.how_much, description = locales.desc_how_much, required = true },
        })
        if not recipeInput then return end
        recipetable[#recipetable + 1] = { item = recipeInput[1], label = recipeInput[2], amount = recipeInput[3] }
    end
    return recipetable
end

AddEventHandler("forge-crafting:CreateMenu", function()
    pr_lib.callback.trigger('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then return end

        pr_lib.callback.trigger('forge-crafting:getBenchModels', function(benchModels)
            local modelOptions = {}
            local modelsBySlug = {}

            for _, bm in ipairs(benchModels or {}) do
                modelsBySlug[bm.slug] = bm
                local optLabel = string.format("%s (%s)", bm.label or bm.slug, bm.model or "")
                modelOptions[#modelOptions + 1] = {
                    label = optLabel,
                    value = bm.slug
                }
            end

            if #modelOptions == 0 then
                modelOptions[1] = { label = "Padrão (xm3_prop_xm3_bench_04b)", value = "default" }
            end

            local input = pr_lib.inputDialog(locales.creation_menu or "Criar Bancada de Crafting", {
                { type = 'input', label = locales.table_name or "Nome da Bancada", placeholder = locales.desc_tablename or "Ex: Armaria Central", required = true, icon = "signature" },
                { type = 'select', label = "Perfil da Bancada", description = "Selecione o modelo 3D pré-configurado e calibrado", options = modelOptions, default = modelOptions[1].value, required = true, searchable = true, icon = "fa-solid fa-cubes" },
                { type = "checkbox", label = "Restringir por Emprego ou Facção", checked = false },
                { type = "checkbox", label = locales.blip or "Criar Blip no Mapa", checked = false },
            })
            if not input then return TriggerEvent('forge-crafting:EditMenu') end

            local benchName = input[1]
            local selectedSlug = input[2]
            local jobRequire = input[3] == true
            local blipRequire = input[4] == true

            local selectedProfile = modelsBySlug[selectedSlug]
            local propModel = selectedProfile and selectedProfile.model or "xm3_prop_xm3_bench_04b"

            pr_lib.callback.trigger("forge-crafting:TableExist", function(exist)
                if exist then return notify(locales.main_title or "Crafting", locales.already_exist or "Uma bancada com este nome já existe.", "error") end

                local blip_data = nil
                local jobData = nil

                local function proceedToPlacement()
                    placeBenchWithGizmo(propModel, nil, nil, "Posicionar Nova Bancada: " .. tostring(benchName), function(coords, heading, confirmed)
                        if confirmed and coords then
                            local newData = {
                                craft_name = benchName,
                                prop = propModel,
                                model_slug = selectedSlug,
                                jobrequire = jobRequire,
                                requireblip = blipRequire,
                                blip = blip_data,
                                jobs = jobData,
                                propcoords = vector3(coords.x, coords.y, coords.z),
                                heading = heading,
                                jobenable = jobRequire,
                                blipenable = blipRequire
                            }
                            TriggerServerEvent("forge-crafting:CreateWorkShop", newData)
                            notify(locales.main_title or "Crafting", locales.success_created or "Bancada criada com sucesso!", "success")
                            Wait(100)
                            TriggerServerEvent("forge-crafting:Update")
                            TriggerEvent('forge-crafting:EditMenu')
                        else
                            TriggerEvent('forge-crafting:EditMenu')
                        end
                    end)
                end

                local function handleBlipAndPlace()
                    if blipRequire then
                        local blip = pr_lib.inputDialog(locales.blip_creation or "Criar Blip", {
                            { type = 'number', label = locales.blip_sprite or "Ícone (Sprite)", required = true, max = 883, min = 0, default = 566 },
                            { type = 'number', label = locales.blip_colour or "Cor do Blip", required = true, max = 85, min = 0, default = 0 },
                            { type = 'input', label = locales.blip_scale or "Escala", required = true, default = "0.7" },
                            { type = 'input', label = locales.blip_label or "Nome do Blip", required = true, default = benchName, icon = "signature" },
                        })
                        if blip then
                            blip_data = { sprite = blip[1], colour = blip[2], scale = tonumber(blip[3]) or 0.7, blip_label = blip[4] }
                        end
                    end
                    proceedToPlacement()
                end

                if jobRequire then
                    openJobConfigurationDialog(function(configuredJob)
                        if not configuredJob then
                            return notify(locales.main_title or "Crafting", "Configuração de emprego/facção cancelada.", "inform")
                        end
                        jobData = configuredJob
                        handleBlipAndPlace()
                    end)
                else
                    handleBlipAndPlace()
                end
            end, benchName)
        end)
    end)
end)

function GetBaseItems()
    local items = {}
    local rawItems = pr_lib.inventory and pr_lib.inventory.Items and pr_lib.inventory.Items() or {}
    for k, v in pairs(rawItems) do
        local label = type(v) == "table" and (v.label or k) or tostring(v)
        items[#items + 1] = {
            value = k,
            label = string.format('%s (%s)', label, k)
        }
    end
    return items
end

local CurrentClientTheme = {}

function GetCurrentTheme()
    return CurrentClientTheme
end

local function parseColorAndAlpha(colorStr, defaultHex, defaultAlpha)
    defaultHex = defaultHex or "#38bdf8"
    defaultAlpha = defaultAlpha or 100

    if not colorStr or type(colorStr) ~= "string" or colorStr == "" then
        return defaultHex, defaultAlpha
    end

    if colorStr == "transparent" then
        return defaultHex, 0
    end

    -- Match rgba(r, g, b, a) or rgb(r, g, b)
    local r, g, b, a = colorStr:match("rgba?%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,?%s*([%d%.]*)%s*%)")
    if r and g and b then
        local rNum = tonumber(r) or 0
        local gNum = tonumber(g) or 0
        local bNum = tonumber(b) or 0
        local alpha = 100
        if a and a ~= "" then
            local aNum = tonumber(a)
            if aNum then
                alpha = math.floor(aNum * 100 + 0.5)
            end
        end
        return string.format("#%02x%02x%02x", rNum, gNum, bNum), alpha
    end

    -- Match hex (#RGB, #RRGGBB, #RRGGBBAA)
    local hexOnly = colorStr:match("#?([%da-fA-F]+)")
    if hexOnly then
        if #hexOnly == 3 then
            local rH = hexOnly:sub(1, 1):rep(2)
            local gH = hexOnly:sub(2, 2):rep(2)
            local bH = hexOnly:sub(3, 3):rep(2)
            return "#" .. rH .. gH .. bH, 100
        elseif #hexOnly == 6 then
            return "#" .. hexOnly, 100
        elseif #hexOnly == 8 then
            local hexRgb = "#" .. hexOnly:sub(1, 6)
            local aNum = tonumber(hexOnly:sub(7, 8), 16) or 255
            local alpha = math.floor((aNum / 255) * 100 + 0.5)
            return hexRgb, alpha
        end
    end

    return defaultHex, defaultAlpha
end

local function formatColorWithAlpha(colorVal, alphaPercent)
    alphaPercent = tonumber(alphaPercent) or 100
    if alphaPercent <= 0 then
        return "transparent"
    end

    if not colorVal or type(colorVal) ~= "string" or colorVal == "" then
        colorVal = "#ffffff"
    end

    -- If colorVal has rgb or rgba
    local r, g, b = colorVal:match("rgba?%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)")
    if r and g and b then
        local rNum = tonumber(r) or 0
        local gNum = tonumber(g) or 0
        local bNum = tonumber(b) or 0
        local a = alphaPercent / 100.0
        if alphaPercent >= 100 then
            return string.format("#%02x%02x%02x", rNum, gNum, bNum)
        else
            return string.format("rgba(%d, %d, %d, %.2f)", rNum, gNum, bNum, a)
        end
    end

    -- If colorVal is hex
    local cleanHex = colorVal:gsub("#", "")
    if #cleanHex >= 6 then
        local rNum = tonumber(cleanHex:sub(1, 2), 16) or 255
        local gNum = tonumber(cleanHex:sub(3, 4), 16) or 255
        local bNum = tonumber(cleanHex:sub(5, 6), 16) or 255
        local a = alphaPercent / 100.0
        if alphaPercent >= 100 then
            return string.format("#%02x%02x%02x", rNum, gNum, bNum)
        else
            return string.format("rgba(%d, %d, %d, %.2f)", rNum, gNum, bNum, a)
        end
    elseif #cleanHex == 3 then
        local rNum = tonumber(cleanHex:sub(1, 1):rep(2), 16) or 255
        local gNum = tonumber(cleanHex:sub(2, 2):rep(2), 16) or 255
        local bNum = tonumber(cleanHex:sub(3, 3):rep(2), 16) or 255
        local a = alphaPercent / 100.0
        if alphaPercent >= 100 then
            return string.format("#%02x%02x%02x", rNum, gNum, bNum)
        else
            return string.format("rgba(%d, %d, %d, %.2f)", rNum, gNum, bNum, a)
        end
    end

    return colorVal
end

function OpenThemeCustomizationMenu()
    pr_lib.callback.trigger('forge-crafting:getStandbyConfig', function(cfg)
        cfg = cfg or {}
        local themeOptions = {
            {
                title = "Tela de Repouso (Standby)",
                icon = "tv",
                description = "Logo, títulos, cor de fundo, opacidade, imagem de fundo e neon do modo repouso.",
                arrow = true,
                onSelect = function()
                    local bgHex, bgAlpha = parseColorAndAlpha(cfg.standby_bg, "#0a0e17", 95)
                    local glowHex, glowAlpha = parseColorAndAlpha(cfg.standby_glow_color, "#38bdf8", 15)
                    local borderHex, borderAlpha = parseColorAndAlpha(cfg.standby_border_color, "#38bdf8", 25)
                    local titleHex = parseColorAndAlpha(cfg.standby_title_color, "#f8fafc", 100)
                    local subtitleHex = parseColorAndAlpha(cfg.standby_subtitle_color, "#38bdf8", 100)

                    local d = pr_lib.inputDialog("Personalizar Modo Repouso (Standby)", {
                        { type = 'input', label = "URL da Logo", default = cfg.logo or 'https://i.ibb.co/sphpgQs6/forge-flame.png', required = true, icon = 'link' },
                        { type = 'input', label = "Título Principal", default = cfg.title or 'FORGE CRAFTING', required = false, icon = 'heading' },
                        { type = 'input', label = "Subtítulo / Rodapé", default = cfg.subtitle or 'BANCADA DE TRABALHO', required = false, icon = 'subscript' },
                        { type = 'color', label = "Cor de Fundo", default = bgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade do Fundo (%)", default = bgAlpha, min = 0, max = 100, step = 1, description = "0 = Transparente, 100 = Opaco" },
                        { type = 'input', label = "URL de Imagem de Fundo (opcional)", default = cfg.standby_bg_image or '', required = false, icon = 'image' },
                        { type = 'color', label = "Cor do Brilho / Glow Neon", default = glowHex, format = 'hex' },
                        { type = 'slider', label = "Intensidade do Glow Neon (%)", default = glowAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor da Borda", default = borderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade da Borda (%)", default = borderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor do Título", default = titleHex, format = 'hex' },
                        { type = 'color', label = "Cor do Subtítulo", default = subtitleHex, format = 'hex' },
                    })
                    if not d then return OpenThemeCustomizationMenu() end
                    cfg.logo = d[1]
                    cfg.title = d[2]
                    cfg.subtitle = d[3]
                    cfg.standby_bg = formatColorWithAlpha(d[4], d[5])
                    cfg.standby_bg_image = d[6] or ''
                    cfg.standby_glow_color = formatColorWithAlpha(d[7], d[8])
                    cfg.standby_border_color = formatColorWithAlpha(d[9], d[10])
                    cfg.standby_title_color = tostring(d[11] or titleHex)
                    cfg.standby_subtitle_color = tostring(d[12] or subtitleHex)
                    TriggerServerEvent('forge-crafting:UpdateStandbyConfig', cfg)
                    Wait(150)
                    OpenThemeCustomizationMenu()
                end
            },
            {
                title = "Fundo e Moldura da Bancada Ativa",
                icon = "window-maximize",
                description = "Fundo da janela (com seletor e trackbar de transparência), imagem de fundo, borda e neon.",
                arrow = true,
                onSelect = function()
                    local bgHex, bgAlpha = parseColorAndAlpha(cfg.bench_bg, "#0f141d", 95)
                    local borderHex, borderAlpha = parseColorAndAlpha(cfg.bench_border_color, "#ffffff", 12)
                    local neonHex, neonAlpha = parseColorAndAlpha(cfg.bench_neon_color, "#38bdf8", 100)

                    local d = pr_lib.inputDialog("Fundo e Moldura da Bancada", {
                        { type = 'color', label = "Cor de Fundo da Janela", default = bgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade do Fundo (%)", default = bgAlpha, min = 0, max = 100, step = 1, description = "0 = Fundo 100% Transparente, 100 = Opaco" },
                        { type = 'input', label = "URL de Imagem de Fundo (opcional)", default = cfg.bench_bg_image or '', required = false, icon = 'image' },
                        { type = 'color', label = "Cor da Borda da Janela", default = borderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade da Borda (%)", default = borderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor do Neon / Iluminação Geral", default = neonHex, format = 'hex' },
                        { type = 'slider', label = "Intensidade do Neon (%)", default = neonAlpha, min = 0, max = 100, step = 1, description = "0 = Sem neon, 100 = Brilho máximo" },
                    })
                    if not d then return OpenThemeCustomizationMenu() end
                    cfg.bench_bg = formatColorWithAlpha(d[1], d[2])
                    cfg.bench_bg_image = d[3] or ''
                    cfg.bench_border_color = formatColorWithAlpha(d[4], d[5])
                    cfg.bench_neon_color = formatColorWithAlpha(d[6], d[7])
                    TriggerServerEvent('forge-crafting:UpdateStandbyConfig', cfg)
                    Wait(150)
                    OpenThemeCustomizationMenu()
                end
            },
            {
                title = "Cabeçalho, Nível e Busca",
                icon = "magnifying-glass",
                description = "Cores do nome da bancada, badge de nível do jogador e campo de busca.",
                arrow = true,
                onSelect = function()
                    local titleHex = parseColorAndAlpha(cfg.header_title_color, "#f8fafc", 100)
                    local subtitleHex = parseColorAndAlpha(cfg.header_subtitle_color, "#94a3b8", 100)
                    local badgeBgHex, badgeBgAlpha = parseColorAndAlpha(cfg.level_badge_bg, "#1e293b", 70)
                    local badgeColorHex = parseColorAndAlpha(cfg.level_badge_color, "#38bdf8", 100)
                    local searchBgHex, searchBgAlpha = parseColorAndAlpha(cfg.search_bg, "#0f172a", 60)
                    local searchBorderHex, searchBorderAlpha = parseColorAndAlpha(cfg.search_border, "#ffffff", 8)
                    local searchTextColorHex = parseColorAndAlpha(cfg.search_text_color, "#f1f5f9", 100)

                    local d = pr_lib.inputDialog("Cabeçalho, Nível e Busca", {
                        { type = 'color', label = "Cor do Título da Bancada", default = titleHex, format = 'hex' },
                        { type = 'color', label = "Cor do Subtítulo", default = subtitleHex, format = 'hex' },
                        { type = 'color', label = "Fundo do Badge de Nível/Maestria", default = badgeBgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Fundo do Badge (%)", default = badgeBgAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor do Texto de Nível/Maestria", default = badgeColorHex, format = 'hex' },
                        { type = 'color', label = "Fundo do Campo de Busca", default = searchBgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Fundo da Busca (%)", default = searchBgAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Borda do Campo de Busca", default = searchBorderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Borda da Busca (%)", default = searchBorderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor do Texto da Busca", default = searchTextColorHex, format = 'hex' },
                    })
                    if not d then return OpenThemeCustomizationMenu() end
                    cfg.header_title_color = tostring(d[1] or titleHex)
                    cfg.header_subtitle_color = tostring(d[2] or subtitleHex)
                    cfg.level_badge_bg = formatColorWithAlpha(d[3], d[4])
                    cfg.level_badge_color = tostring(d[5] or badgeColorHex)
                    cfg.search_bg = formatColorWithAlpha(d[6], d[7])
                    cfg.search_border = formatColorWithAlpha(d[8], d[9])
                    cfg.search_text_color = tostring(d[10] or searchTextColorHex)
                    TriggerServerEvent('forge-crafting:UpdateStandbyConfig', cfg)
                    Wait(150)
                    OpenThemeCustomizationMenu()
                end
            },
            {
                title = "Cards de Receitas e Selecionado",
                icon = "list-check",
                description = "Cores dos cards da lista de receitas e destaque/neon do card selecionado.",
                arrow = true,
                onSelect = function()
                    local cardBgHex, cardBgAlpha = parseColorAndAlpha(cfg.recipe_card_bg, "#ffffff", 2)
                    local cardBorderHex, cardBorderAlpha = parseColorAndAlpha(cfg.recipe_card_border, "#ffffff", 5)
                    local activeBgHex, activeBgAlpha = parseColorAndAlpha(cfg.recipe_card_active_bg, "#3b82f6", 18)
                    local activeBorderHex, activeBorderAlpha = parseColorAndAlpha(cfg.recipe_card_active_border, "#3b82f6", 100)
                    local activeGlowHex, activeGlowAlpha = parseColorAndAlpha(cfg.recipe_card_active_glow, "#3b82f6", 25)

                    local d = pr_lib.inputDialog("Cards de Receitas", {
                        { type = 'color', label = "Fundo dos Cards de Receitas", default = cardBgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Fundo dos Cards (%)", default = cardBgAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Borda dos Cards de Receitas", default = cardBorderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Borda dos Cards (%)", default = cardBorderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Fundo do Card Selecionado (Ativo)", default = activeBgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Fundo Selecionado (%)", default = activeBgAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Borda do Card Selecionado (Neon)", default = activeBorderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Borda Selecionada (%)", default = activeBorderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Glow / Brilho do Card Selecionado", default = activeGlowHex, format = 'hex' },
                        { type = 'slider', label = "Intensidade do Glow do Card (%)", default = activeGlowAlpha, min = 0, max = 100, step = 1 },
                    })
                    if not d then return OpenThemeCustomizationMenu() end
                    cfg.recipe_card_bg = formatColorWithAlpha(d[1], d[2])
                    cfg.recipe_card_border = formatColorWithAlpha(d[3], d[4])
                    cfg.recipe_card_active_bg = formatColorWithAlpha(d[5], d[6])
                    cfg.recipe_card_active_border = formatColorWithAlpha(d[7], d[8])
                    cfg.recipe_card_active_glow = formatColorWithAlpha(d[9], d[10])
                    TriggerServerEvent('forge-crafting:UpdateStandbyConfig', cfg)
                    Wait(150)
                    OpenThemeCustomizationMenu()
                end
            },
            {
                title = "Botão de Fabricar Item",
                icon = "hammer",
                description = "Cor de fundo, hover, brilho neon e texto do botão FABRICAR.",
                arrow = true,
                onSelect = function()
                    local btnBgHex, btnBgAlpha = parseColorAndAlpha(cfg.craft_btn_bg, "#3b82f6", 100)
                    local btnHoverHex, btnHoverAlpha = parseColorAndAlpha(cfg.craft_btn_hover, "#60a5fa", 100)
                    local btnGlowHex, btnGlowAlpha = parseColorAndAlpha(cfg.craft_btn_glow, "#2563eb", 35)
                    local btnTextHex = parseColorAndAlpha(cfg.craft_btn_text, "#ffffff", 100)

                    local d = pr_lib.inputDialog("Botão Fabricar Item", {
                        { type = 'color', label = "Cor Principal do Botão", default = btnBgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade do Botão (%)", default = btnBgAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor no Hover (Mouse sobre o Botão)", default = btnHoverHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade no Hover (%)", default = btnHoverAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor do Brilho / Glow Neon", default = btnGlowHex, format = 'hex' },
                        { type = 'slider', label = "Intensidade do Glow do Botão (%)", default = btnGlowAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor do Texto do Botão", default = btnTextHex, format = 'hex' },
                    })
                    if not d then return OpenThemeCustomizationMenu() end
                    cfg.craft_btn_bg = formatColorWithAlpha(d[1], d[2])
                    cfg.craft_btn_hover = formatColorWithAlpha(d[3], d[4])
                    cfg.craft_btn_glow = formatColorWithAlpha(d[5], d[6])
                    cfg.craft_btn_text = tostring(d[7] or btnTextHex)
                    TriggerServerEvent('forge-crafting:UpdateStandbyConfig', cfg)
                    Wait(150)
                    OpenThemeCustomizationMenu()
                end
            },
            {
                title = "Materiais Requeridos & Detalhes",
                icon = "boxes-stacked",
                description = "Cores dos cards de insumos (suficiente vs em falta), bordas, detalhes e cor do XP.",
                arrow = true,
                onSelect = function()
                    local matCardBgHex, matCardBgAlpha = parseColorAndAlpha(cfg.mat_card_bg, "#ffffff", 2)
                    local matSufBorderHex, matSufBorderAlpha = parseColorAndAlpha(cfg.mat_card_sufficient_border, "#22c55e", 25)
                    local matSufTextHex = parseColorAndAlpha(cfg.mat_card_sufficient_color, "#4ade80", 100)
                    local matInsufBorderHex, matInsufBorderAlpha = parseColorAndAlpha(cfg.mat_card_insufficient_border, "#ef4444", 25)
                    local matInsufTextHex = parseColorAndAlpha(cfg.mat_card_insufficient_color, "#f87171", 100)
                    local detailBgHex, detailBgAlpha = parseColorAndAlpha(cfg.detail_card_bg, "#1e293b", 40)
                    local detailBorderHex, detailBorderAlpha = parseColorAndAlpha(cfg.detail_card_border, "#ffffff", 8)
                    local detailXpHex = parseColorAndAlpha(cfg.detail_xp_color, "#38bdf8", 100)

                    local d = pr_lib.inputDialog("Materiais e Detalhes", {
                        { type = 'color', label = "Fundo dos Cards de Insumos", default = matCardBgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Insumos (%)", default = matCardBgAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Borda - Material Suficiente", default = matSufBorderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Borda Suficiente (%)", default = matSufBorderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Texto/Ícone - Material Suficiente", default = matSufTextHex, format = 'hex' },
                        { type = 'color', label = "Borda - Material Insuficiente", default = matInsufBorderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Borda Insuficiente (%)", default = matInsufBorderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Texto/Ícone - Material Insuficiente", default = matInsufTextHex, format = 'hex' },
                        { type = 'color', label = "Fundo do Card de Detalhes", default = detailBgHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Card Detalhes (%)", default = detailBgAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Borda do Card de Detalhes", default = detailBorderHex, format = 'hex' },
                        { type = 'slider', label = "Opacidade Borda Detalhes (%)", default = detailBorderAlpha, min = 0, max = 100, step = 1 },
                        { type = 'color', label = "Cor do Badge de XP (+XP)", default = detailXpHex, format = 'hex' },
                    })
                    if not d then return OpenThemeCustomizationMenu() end
                    cfg.mat_card_bg = formatColorWithAlpha(d[1], d[2])
                    cfg.mat_card_sufficient_border = formatColorWithAlpha(d[3], d[4])
                    cfg.mat_card_sufficient_color = tostring(d[5] or matSufTextHex)
                    cfg.mat_card_insufficient_border = formatColorWithAlpha(d[6], d[7])
                    cfg.mat_card_insufficient_color = tostring(d[8] or matInsufTextHex)
                    cfg.detail_card_bg = formatColorWithAlpha(d[9], d[10])
                    cfg.detail_card_border = formatColorWithAlpha(d[11], d[12])
                    cfg.detail_xp_color = tostring(d[13] or detailXpHex)
                    TriggerServerEvent('forge-crafting:UpdateStandbyConfig', cfg)
                    Wait(150)
                    OpenThemeCustomizationMenu()
                end
            },
            {
                title = "Cores dos Textos da Interface (DUI)",
                icon = "font",
                description = "Configure a cor principal dos textos, títulos, metadados e rótulos das linhas da arma (escuros por padrão).",
                arrow = true,
                onSelect = function()
                    local primHex = parseColorAndAlpha(cfg.text_primary, "#0f172a", 100)
                    local secHex = parseColorAndAlpha(cfg.text_secondary, "#334155", 100)
                    local headHex = parseColorAndAlpha(cfg.text_headings, "#020617", 100)
                    local calloutHex = parseColorAndAlpha(cfg.text_callout, "#0f172a", 100)

                    local d = pr_lib.inputDialog("Cores dos Textos da Interface", {
                        { type = 'color', label = "Cor Principal dos Textos (Nomes de Itens, Abas)", default = primHex, format = 'hex' },
                        { type = 'color', label = "Cor dos Títulos de Seções e Cabeçalhos", default = headHex, format = 'hex' },
                        { type = 'color', label = "Cor Secundária / Metadados (Tempo, Serial, Contadores)", default = secHex, format = 'hex' },
                        { type = 'color', label = "Cor dos Rótulos das Linhas (Mira, Silenciador...)", default = calloutHex, format = 'hex' },
                    })
                    if not d then return OpenThemeCustomizationMenu() end
                    cfg.text_primary = tostring(d[1] or primHex)
                    cfg.text_headings = tostring(d[2] or headHex)
                    cfg.text_secondary = tostring(d[3] or secHex)
                    cfg.text_callout = tostring(d[4] or calloutHex)
                    TriggerServerEvent('forge-crafting:UpdateStandbyConfig', cfg)
                    Wait(150)
                    OpenThemeCustomizationMenu()
                end
            },
            {
                title = "Restaurar Visual Padrão",
                icon = "rotate-left",
                description = "Restaura todas as cores, neon e estilos para o padrão moderno de fábrica.",
                onSelect = function()
                    local alert = pr_lib.alertDialog({
                        header = "Restaurar Padrão",
                        content = "Deseja restaurar todas as cores e estilos visuais da bancada para o padrão?",
                        centered = true,
                        cancel = true
                    })
                    if alert == "confirm" then
                        local defaultData = {
                            logo = "https://i.ibb.co/sphpgQs6/forge-flame.png",
                            title = "FORGE CRAFTING",
                            subtitle = "BANCADA DE TRABALHO",
                            standby_bg = "radial-gradient(circle at center, rgba(17, 24, 39, 0.96) 0%, rgba(10, 14, 23, 0.98) 100%)",
                            standby_bg_image = "",
                            standby_glow_color = "rgba(56, 189, 248, 0.15)",
                            standby_border_color = "rgba(56, 189, 248, 0.25)",
                            standby_title_color = "#f8fafc",
                            standby_subtitle_color = "#38bdf8",
                            bench_bg = "rgba(15, 20, 29, 0.95)",
                            bench_bg_image = "",
                            bench_border_color = "rgba(255, 255, 255, 0.12)",
                            bench_neon_color = "#38bdf8",
                            header_title_color = "#0f172a",
                            header_subtitle_color = "#334155",
                            level_badge_bg = "rgba(30, 41, 59, 0.7)",
                            level_badge_color = "#38bdf8",
                            search_bg = "rgba(15, 23, 42, 0.6)",
                            search_border = "rgba(255, 255, 255, 0.08)",
                            search_text_color = "#0f172a",
                            recipe_card_bg = "rgba(255, 255, 255, 0.02)",
                            recipe_card_border = "rgba(255, 255, 255, 0.05)",
                            recipe_card_active_bg = "rgba(59, 130, 246, 0.18)",
                            recipe_card_active_border = "#3b82f6",
                            recipe_card_active_glow = "rgba(59, 130, 246, 0.25)",
                            craft_btn_bg = "#3b82f6",
                            craft_btn_hover = "#60a5fa",
                            craft_btn_glow = "rgba(37, 99, 235, 0.35)",
                            craft_btn_text = "#ffffff",
                            mat_card_bg = "rgba(255, 255, 255, 0.02)",
                            mat_card_sufficient_border = "rgba(34, 197, 94, 0.25)",
                            mat_card_sufficient_color = "#4ade80",
                            mat_card_insufficient_border = "rgba(239, 68, 68, 0.25)",
                            mat_card_insufficient_color = "#f87171",
                            detail_card_bg = "rgba(30, 41, 59, 0.4)",
                            detail_card_border = "rgba(255, 255, 255, 0.08)",
                            detail_badge_bg = "rgba(255, 255, 255, 0.04)",
                            detail_badge_color = "#334155",
                            detail_xp_color = "#38bdf8",
                            text_primary = "#0f172a",
                            text_secondary = "#334155",
                            text_headings = "#020617",
                            text_callout = "#0f172a"
                        }
                        TriggerServerEvent('forge-crafting:UpdateStandbyConfig', defaultData)
                        Wait(150)
                        OpenThemeCustomizationMenu()
                    else
                        OpenThemeCustomizationMenu()
                    end
                end
            }
        }

        pr_lib.RegisterContext({
            id = 'theme_customization_menu',
            menu = 'crafting_list',
            title = "Personalizar Cores e Visual",
            options = themeOptions
        })
        pr_lib.showContext('theme_customization_menu')
    end)
end

local function applyStandbyConfig(cfg)
    if not cfg or type(cfg) ~= "table" then return end
    CurrentClientTheme = cfg
    if cfg.logo and cfg.logo ~= "" then Config.StandbyLogo = cfg.logo end
    if cfg.title and cfg.title ~= "" then Config.StandbyTitle = cfg.title end
    if cfg.subtitle and cfg.subtitle ~= "" then Config.StandbySubtitle = cfg.subtitle end

    if UpdateThemeOnAllScreens then
        UpdateThemeOnAllScreens(cfg)
    elseif UpdateAllPassiveScreens then
        UpdateAllPassiveScreens()
    end
end

RegisterNetEvent('forge-crafting:SyncStandbyConfig', applyStandbyConfig)
RegisterNetEvent('forge-crafting:ClientUpdateStandbyConfig', applyStandbyConfig)

CreateThread(function()
    Wait(500)
    pr_lib.callback.trigger('forge-crafting:getStandbyConfig', function(cfg)
        if cfg then
            applyStandbyConfig(cfg)
        end
    end)
end)

-- =====================================================
--  Menu do Catálogo Global de Receitas
-- =====================================================

function OpenRecipeCatalogMenu()
    pr_lib.callback.trigger('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then return end

        pr_lib.callback.trigger('forge-crafting:getRecipeCatalog', function(catalog)
            catalog = catalog or {}
            local catMap = {}
            for _, r in ipairs(catalog) do
                local c = r.category or 'Geral'
                if not catMap[c] then catMap[c] = {} end
                table.insert(catMap[c], r)
            end

            local menuOptions = {
                {
                    title = "Cadastrar Nova Receita no Catálogo",
                    icon = "plus",
                    description = "Crie uma nova receita global que poderá ser vinculada a qualquer bancada.",
                    arrow = true,
                    onSelect = function()
                        local baseItems = GetBaseItems()
                        local input = pr_lib.inputDialog("Nova Receita no Catálogo", {
                            { type = 'select', label = "Item Gerado (ID)", description = "Selecione o item a ser fabricado", options = baseItems, required = true, searchable = true, icon = "cube" },
                            { type = 'input', label = "Nome / Rótulo do Item", placeholder = "Ex: Bateria de Lítio", required = true, icon = "signature" },
                            { type = 'input', label = "Categoria", placeholder = "Ex: Peças, Armas, Ferramentas", default = "Geral", required = true, icon = "folder" },
                            { type = 'number', label = "Quantidade Produzida", default = 1, min = 1, required = true, icon = "hashtag" },
                            { type = 'number', label = "Tempo de Criação (segundos)", default = 5, min = 1, required = true, icon = "clock" },
                            { type = 'number', label = "Quantidade de Ingredientes Distintos", default = 1, min = 1, required = true, icon = "list-ol" },
                            { type = 'input', label = "Modelo 3D no Mundo (opcional)", placeholder = "Ex: prop_cs_box_clothes", required = false, icon = "box" },
                            { type = 'input', label = "Animação de Craft (opcional)", placeholder = "Ex: idle_01_amy_skater_01", required = false, icon = "person-walking" },
                            { type = 'number', label = "Nível Mínimo Exigido", default = 0, min = 0, required = false, icon = "ranking-star" },
                            { type = 'number', label = "XP Concedido", default = 10, min = 0, required = false, icon = "award" },
                        })

                        if not input then return OpenRecipeCatalogMenu() end

                        local numIngs = tonumber(input[6]) or 1
                        local recipeTable = createRecipe(numIngs)
                        if not recipeTable then return OpenRecipeCatalogMenu() end

                        local recData = {
                            item = input[1],
                            item_label = input[2],
                            category = input[3] or "Geral",
                            amount = tonumber(input[4]) or 1,
                            time = tonumber(input[5]) or 5,
                            recipe = recipeTable,
                            model = input[7] and input[7] ~= "" and input[7] or nil,
                            anim = input[8] and input[8] ~= "" and input[8] or nil,
                            level = input[9] and tonumber(input[9]) or 0,
                            xp = input[10] and tonumber(input[10]) or 10,
                        }

                        pr_lib.callback.trigger('forge-crafting:saveRecipeToCatalog', function(ok, msg)
                            if ok then
                                notify(locales.main_title or "Crafting", msg or "Receita salva no catálogo!", "success")
                            else
                                notify(locales.main_title or "Crafting", msg or "Erro ao salvar receita.", "error")
                            end
                            Wait(150)
                            OpenRecipeCatalogMenu()
                        end, recData)
                    end
                },
                {
                    title = "Importar Receitas dos Arquivos (Peças & Tuning)",
                    icon = "file-import",
                    description = "Importa ou atualiza todas as receitas padrão definidas nos arquivos shared/receita_nova e shared/receita_tuning.",
                    arrow = true,
                    onSelect = function()
                        local confirm = pr_lib.alertDialog({
                            header = "Importar Receitas Padrão",
                            content = "Deseja importar todas as receitas de peças e tuning para o catálogo global? Receitas existentes serão atualizadas.",
                            centered = true,
                            cancel = true
                        })
                        if confirm == "confirm" then
                            pr_lib.callback.trigger('forge-crafting:importSharedRecipesToCatalog', function(ok, count)
                                Wait(200)
                                OpenRecipeCatalogMenu()
                            end)
                        else
                            OpenRecipeCatalogMenu()
                        end
                    end
                }
            }

            -- Adicionar seletor por categoria para navegação rápida
            local categories = {}
            for cat, _ in pairs(catMap) do
                table.insert(categories, cat)
            end
            table.sort(categories)

            for _, cat in ipairs(categories) do
                local recList = catMap[cat]
                menuOptions[#menuOptions + 1] = {
                    title = string.format("Categoria: %s (%d receitas)", cat, #recList),
                    icon = "folder-open",
                    description = string.format("Visualizar e gerenciar as %d receitas desta categoria.", #recList),
                    arrow = true,
                    onSelect = function()
                        OpenCatalogCategoryList(cat, recList)
                    end
                }
            end

            pr_lib.RegisterContext({
                id = 'forge_recipe_catalog_main',
                menu = 'crafting_list',
                title = "Catálogo Global de Receitas (" .. #catalog .. " total)",
                options = menuOptions
            })
            pr_lib.showContext('forge_recipe_catalog_main')
        end)
    end)
end

function OpenCatalogCategoryList(categoryName, recipes)
    local options = {}

    for _, rec in ipairs(recipes) do
        local ingCount = (rec.recipe and type(rec.recipe) == "table") and #rec.recipe or 0
        local desc = string.format("Qtd: %d | Tempo: %ds | Nível: %d | XP: %d | Insumos: %d", rec.amount or 1, rec.time or 5, rec.level or 0, rec.xp or 10, ingCount)

        options[#options + 1] = {
            title = rec.item_label or rec.item,
            description = desc,
            icon = "cube",
            arrow = true,
            metadata = {
                { label = "ID do Item", value = rec.item },
                { label = "Categoria", value = rec.category or "Geral" },
            },
            onSelect = function()
                OpenCatalogRecipeDetails(rec, categoryName, recipes)
            end
        }
    end

    pr_lib.RegisterContext({
        id = 'forge_recipe_catalog_cat_' .. categoryName:gsub("%s+", "_"),
        menu = 'forge_recipe_catalog_main',
        title = "Receitas: " .. categoryName,
        options = options
    })
    pr_lib.showContext('forge_recipe_catalog_cat_' .. categoryName:gsub("%s+", "_"))
end

function OpenCatalogRecipeDetails(rec, returnCategory, categoryRecipes)
    local ingText = ""
    if rec.recipe and type(rec.recipe) == "table" then
        for i, ing in ipairs(rec.recipe) do
            local ingName = ing.label or ing.item_label or ing.item or "Item"
            ingText = ingText .. string.format("\n• %s x%d", ingName, tonumber(ing.amount) or 1)
        end
    end
    if ingText == "" then ingText = "Nenhum ingrediente configurado." end

    local detailsOptions = {
        {
            title = "Ingredientes Necessários",
            icon = "receipt",
            description = ingText:gsub("^\n", ""),
            disabled = false,
        },
        {
            title = "Editar Dados Básicos",
            icon = "pen-to-square",
            description = "Altere o rótulo, categoria, quantidade, tempo, nível e XP.",
            arrow = true,
            onSelect = function()
                local edit = pr_lib.inputDialog("Editar Receita: " .. (rec.item_label or rec.item), {
                    { type = 'input', label = "Nome / Rótulo do Item", default = rec.item_label or rec.item, required = true, icon = "signature" },
                    { type = 'input', label = "Categoria", default = rec.category or "Geral", required = true, icon = "folder" },
                    { type = 'number', label = "Quantidade Produzida", default = rec.amount or 1, min = 1, required = true, icon = "hashtag" },
                    { type = 'number', label = "Tempo de Criação (segundos)", default = rec.time or 5, min = 1, required = true, icon = "clock" },
                    { type = 'number', label = "Nível Mínimo", default = rec.level or 0, min = 0, required = false, icon = "ranking-star" },
                    { type = 'number', label = "XP Concedido", default = rec.xp or 10, min = 0, required = false, icon = "award" },
                })
                if not edit then return OpenCatalogRecipeDetails(rec, returnCategory, categoryRecipes) end

                rec.item_label = edit[1]
                rec.category = edit[2]
                rec.amount = tonumber(edit[3]) or 1
                rec.time = tonumber(edit[4]) or 5
                rec.level = tonumber(edit[5]) or 0
                rec.xp = tonumber(edit[6]) or 10

                pr_lib.callback.trigger('forge-crafting:saveRecipeToCatalog', function(ok, msg)
                    if ok then
                        notify(locales.main_title or "Crafting", "Receita atualizada no catálogo!", "success")
                    end
                    Wait(150)
                    OpenRecipeCatalogMenu()
                end, rec)
            end
        },
        {
            title = "Editar Ingredientes da Receita",
            icon = "list-check",
            description = "Recrie a lista de ingredientes necessários.",
            arrow = true,
            onSelect = function()
                local numInput = pr_lib.inputDialog("Ingredientes da Receita", {
                    { type = 'number', label = "Quantidade de Ingredientes Distintos", default = #(rec.recipe or {}) > 0 and #(rec.recipe or {}) or 1, min = 1, required = true }
                })
                if not numInput then return OpenCatalogRecipeDetails(rec, returnCategory, categoryRecipes) end

                local newRecipeTable = createRecipe(tonumber(numInput[1]) or 1)
                if not newRecipeTable then return OpenCatalogRecipeDetails(rec, returnCategory, categoryRecipes) end

                rec.recipe = newRecipeTable
                pr_lib.callback.trigger('forge-crafting:saveRecipeToCatalog', function(ok, msg)
                    if ok then
                        notify(locales.main_title or "Crafting", "Ingredientes atualizados!", "success")
                    end
                    Wait(150)
                    OpenCatalogRecipeDetails(rec, returnCategory, categoryRecipes)
                end, rec)
            end
        },
        {
            title = "Excluir do Catálogo",
            icon = "trash",
            description = "Remove permanentemente esta receita do catálogo global.",
            arrow = true,
            onSelect = function()
                local confirm = pr_lib.alertDialog({
                    header = "Excluir Receita",
                    content = string.format("Tem certeza que deseja excluir a receita '%s' do catálogo global?", rec.item_label or rec.item),
                    centered = true,
                    cancel = true
                })
                if confirm == "confirm" then
                    pr_lib.callback.trigger('forge-crafting:deleteRecipeFromCatalog', function(ok, msg)
                        notify(locales.main_title or "Crafting", msg or "Receita removida.", "success")
                        Wait(150)
                        OpenRecipeCatalogMenu()
                    end, rec.item)
                else
                    OpenCatalogRecipeDetails(rec, returnCategory, categoryRecipes)
                end
            end
        }
    }

    pr_lib.RegisterContext({
        id = 'forge_recipe_catalog_detail_' .. tostring(rec.id or rec.item),
        menu = 'forge_recipe_catalog_cat_' .. returnCategory:gsub("%s+", "_"),
        title = rec.item_label or rec.item,
        options = detailsOptions
    })
    pr_lib.showContext('forge_recipe_catalog_detail_' .. tostring(rec.id or rec.item))
end

RegisterNetEvent('forge-crafting:RecipeCatalogMenu', function()
    OpenRecipeCatalogMenu()
end)
