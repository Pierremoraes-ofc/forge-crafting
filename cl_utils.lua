local raycast = lib.require('bridge.client.raycast')

local function registerCraftingCommand(command, event)
    if not command or command == '' then return end

    RegisterCommand(command, function()
        TriggerEvent(event)
    end)
end

registerCraftingCommand(Config.Pfx .. Config.CreateTableCommand, "forge-crafting:CreateMenu")
registerCraftingCommand(Config.Pfx .. Config.EditMenuCommand, "forge-crafting:EditMenu")

if Config.Pfx ~= '' then
    registerCraftingCommand(Config.CreateTableCommand, "forge-crafting:CreateMenu")
    registerCraftingCommand(Config.EditMenuCommand, "forge-crafting:EditMenu")
end

AddEventHandler('forge-crafting:EditMenu', function()
    QT.TriggerCallback('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then return end
        QT.TriggerCallback('forge-crafting:GetList', function(data)
            local options = {}
            -- Criar uma nova mesa de crafting
            options[#options + 1] = {
                title = locales.new_crafting_table,
                icon = 'plus',
                event = 'forge-crafting:CreateMenu',
                description = locales.desc_new_crafting_table,
                arrow = true
            }
    
            if data then
                for i = 1, #data do
                    local dat = data[i]
                    options[#options + 1] = {
                        title = dat.craft_name,
                        icon = 'wrench',
                        event = 'forge-crafting:OpenEditFunctions',
                        description = locales.listdescription,
                        arrow = true,
                        args = { 
                            craft_name = dat.craft_name, 
                            craft_id = dat.craft_id, 
                            jobs = dat.jobs, 
                            offset = dat.offset, 
                            targetable = dat.targetable 
                        }
                    }
                end
            end
            lib.registerContext({
                id = 'crafting_list',
                menu = 'menu_crafting',
                title = locales.list,
                options = options
            })
            lib.showContext('crafting_list')
        end)
    end)
end)

AddEventHandler('forge-crafting:OpenEditFunctions', function(args)
    QT.TriggerCallback('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then return end
        lib.registerContext({
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
                        local input = lib.inputDialog(args.craft_name, {
                            { type = 'input', label = locales.new_name, placeholder = locales.desc_new_name, required = true, icon = "signature" },
                        })
                        if not input then return TriggerEvent('forge-crafting:OpenEditFunctions', args) end
                        local warning = lib.alertDialog({
                            header = locales.automaticmessage,
                            content = locales.sure_question .. args.craft_name .. locales.to_question .. input[1] .. "?",
                            centered = true,
                            cancel = true
                        })
                        if warning == "confirm" then
                            TriggerServerEvent("forge-crafting:ChangeName", args.craft_id, input[1])
                            notification(locales.main_title,
                                locales.changedname .. "" .. args.craft_name .. "" .. locales.to_question .. "" .. input[1],
                                types.success)
                            Wait(100)
                            TriggerServerEvent("forge-crafting:Update")
                            TriggerEvent('forge-crafting:EditMenu')
                        else
                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                            notification(locales.main_title, locales.canceled_namechanging, types.info)
                        end
                    end,
                    description = locales.desc_namechange
                },
                {
                    title = locales.change_height,
                    icon = "ruler",
                    metadata = {
                        { label = locales.current_height, value = args.offset },
                    },
                    onSelect = function()
                        local input = lib.inputDialog(locales.change_height, {
                            { type = 'number', label = locales.new_height, icon = "hashtag", default = args.offset, required = true, precision = 2 },
                        })
                        if not input then return TriggerEvent('forge-crafting:OpenEditFunctions', args) end
                        TriggerServerEvent("forge-crafting:UpdateHeight", tonumber(input[1]), args.craft_id)
                        Wait(100)
                        TriggerServerEvent("forge-crafting:Update")
                        TriggerEvent('forge-crafting:EditMenu')
                    end,
                    description = locales.desc_namechange
                },
                {
                    title = locales.items_options_menu,
                    icon = "gears",
                    onSelect = function()
                        -- lib.registerContext({
                        --     id = 'items_menu_configuration',
                        --     title = args.craft_name,
                        --     menu = 'edit_opcije',
                        --     options = {
                        --         {
                        --             title = locales.add_items_craft,
                        --             icon = "plus",
                        --             onSelect = function()
                        --                 local adder = lib.inputDialog(args.craft_name, {
                        --                     {type = 'select', label = locales.item, description = locales.desc_add_1, options = GetBaseItems(), required = true, placeholder = locales.cola_example, searchable = true},
                        --                     {type = 'input', label = locales.item_label, description = locales.desc_add_2, required = true, placeholder = locales.cocacola_example},
                        --                     {type = 'number', label = locales.item_recipe, description = locales.desc_add_3, required = true},
                        --                     {type = 'input', label = locales.time_to_craft, description = locales.desc_add_4, required = true, placeholder = locales.placeholder_itemadd},
                        --                     {type = 'number', label = locales.amount_to_craft, description = locales.desc_add_5, required = true},
                        --                     {type = 'input', label = locales.item_model, description = locales.desc_add_6}
                        --                   })
                        --                   if not adder then return end
                        --                   if tonumber(adder[4]) then
                        --                     local recipee = createRecipe(adder[3])
                        --                     local main_recipe = { craft_id = args.craft_id, main_item = adder[1], item_label = adder[2], recipe = recipee, time = tonumber(adder[4]), amount = adder[5], model = adder[6] }
                        --                     TriggerServerEvent("forge-crafting:AddItemCrafting", main_recipe)
                        --                     notification(locales.main_title, locales.items_added_success, types.success)
                        --                   else
                        --                      notification(locales.main_title, locales.time_must_number, types.error)
                        --                   end
                        --             end,
                        --             description = locales.desc_add
                        --           },
                        --           {
                        --             title = locales.list_itemsa,
                        --             description = locales.desc_listitems,
                        --             icon = "clipboard-user",
                        --             onSelect = function()
                        QT.TriggerCallback('forge-crafting:GetListItems', function(result)
                            if result then
                                local options = {
                                    {
                                        title = locales.add_items_craft,
                                        icon = "plus",
                                        onSelect = function()
                                            local adder = lib.inputDialog(args.craft_name, {
                                                { type = 'select', label = locales.item,            description = locales.desc_add_1, options = GetBaseItems(), required = true,                          placeholder = locales.cola_example, searchable = true },
                                                { type = 'input',  label = locales.item_label,      description = locales.desc_add_2, required = true,          placeholder = locales.cocacola_example },
                                                { type = 'number', label = locales.item_recipe,     description = locales.desc_add_3, required = true },
                                                { type = 'input',  label = locales.time_to_craft,   description = locales.desc_add_4, required = true,          placeholder = locales.placeholder_itemadd },
                                                { type = 'number', label = locales.amount_to_craft, description = locales.desc_add_5, required = true },
                                                { type = 'input',  label = locales.item_model,      description = locales.desc_add_6 },
                                                { type = 'input',  label = locales.item_anim,       description = locales.desc_add_7 }
                                            })
                                            if not adder then return end
                                            if tonumber(adder[4]) then
                                                local recipee = createRecipe(adder[3])
                                                local main_recipe = {
                                                    craft_id = args.craft_id,
                                                    main_item = adder[1],
                                                    item_label = adder[2],
                                                    recipe = recipee,
                                                    time = tonumber(adder[4]),
                                                    amount = adder[5],
                                                    model = adder[6],
                                                    anim = adder[7]
                                                }
                                                TriggerServerEvent("forge-crafting:AddItemCrafting", main_recipe)
                                                notification(locales.main_title, locales.items_added_success, types.success)
                                            else
                                                notification(locales.main_title, locales.time_must_number, types.error)
                                            end
                                        end,
                                        description = locales.desc_add
                                    }
                                }
                                for i = 1, #result do
                                    local someData = result[i]
                                    options[#options + 1] = {
                                        title = someData.item_label,
                                        description = locales.desc_item_optionsss,
                                        icon = "nui://" .. Config.ImagePath .. someData.item .. ".png",
                                        onSelect = function()
                                            lib.registerContext({
                                                id = 'edit_options_items',
                                                title = args.craft_name,
                                                menu = 'items_listiii',
                                                options = {
                                                    {
                                                        title = locales.delete_items,
                                                        -- description = locales.desc_deleteitems,
                                                        icon = "trash",
                                                        iconColor = 'red',
                                                        onSelect = function()
                                                            local warning = lib.alertDialog({
                                                                header = locales.automaticmessage,
                                                                content = locales.automatic_deleteitem ..
                                                                    someData.item_label .. "?",
                                                                centered = true,
                                                                cancel = true
                                                            })
                                                            if warning == "confirm" then
                                                                local deleteData = {
                                                                    craft_id = someData.craft_id,
                                                                    item =
                                                                        someData.item,
                                                                    item_label = someData.item_label
                                                                }
                                                                TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id,
                                                                    someData.item, nil, "delete")
                                                            else
                                                                notification(locales.main_title,
                                                                    locales.canceled_deletingitem, types.info)
                                                            end
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_craft_times,
                                                        -- description = locales.desc_changeeachtime,
                                                        icon = "clock",
                                                        onSelect = function()
                                                            local timer = lib.inputDialog(locales.new_time, {
                                                                { type = 'number', label = locales.enter_time, default = "15", description = "* in seconds *", required = true },
                                                            })
    
                                                            if not timer then return lib.showContext('edit_options_items') end
    
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id,
                                                                someData.item, timer[1], "time")
                                                            Wait(100)
                                                            TriggerServerEvent("forge-crafting:Update")
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_recipe,
                                                        -- description = locales.desc_changerecipe,
                                                        icon = "right-left",
                                                        onSelect = function()
                                                            local updatera = lib.inputDialog(args.craft_name, {
                                                                { type = 'number', label = locales.item_recipe, description = locales.desc_add_3, required = true },
                                                            })
                                                            if not updatera then return lib.showContext('edit_options_items') end
                                                            local recipee = createRecipe(updatera[1])
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id,
                                                                someData.item, recipee, "recipe")
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_item_display,
                                                        -- description = locales.desc_displayname_item,
                                                        icon = "arrow-up-9-1",
                                                        onSelect = function()
                                                            local name = lib.inputDialog(args.craft_name, {
                                                                { type = 'input', label = locales.item_label, placeholder = locales.desc_add_2, required = true },
                                                            })
                                                            if not name then return lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id,
                                                                someData.item, name[1], "label")
                                                        end,
                                                    },
                                                    {
                                                        title = locales.change_reward_amount,
                                                        description = string.format('%s %s', locales.desc_reward_amount,
                                                            someData.amount),
                                                        icon = "scale-unbalanced-flip",
                                                        onSelect = function()
                                                            local amount = lib.inputDialog(args.craft_name, {
                                                                { type = 'number', label = locales.amount_to_craft, placeholder = locales.desc_add_5, default = someData.amount, required = true },
                                                            })
                                                            if not amount then return lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id,
                                                                someData.item, amount[1], "amount")
                                                        end,
                                                    },
                                                    {
                                                        title = locales.item_model,
                                                        description = someData.model or locales.noprop,
                                                        icon = "fa-solid fa-gears",
                                                        onSelect = function()
                                                            local model = lib.inputDialog(args.craft_name, {
                                                                { type = 'input', label = locales.item_model, description = locales.desc_add_6, default = someData.model, required = true },
                                                            })
                                                            if not model then return lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id,
                                                                someData.item, model[1], "model")
                                                        end,
                                                    },
                                                    {
                                                        title = locales.item_anim,
                                                        description = someData.anim or "Default",
                                                        icon = "user",
                                                        onSelect = function()
                                                            local anim = lib.inputDialog(args.craft_name, {
                                                                { type = 'input', label = locales.item_anim, description = locales.desc_add_7, default = someData.anim, required = true },
                                                            })
                                                            if not anim then return lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, anim[1], "anim")
                                                        end,
                                                    },
                                                    -- alterar nível necessário para craftar o item
                                                    {
                                                        title = locales.item_level,
                                                        description = string.format('Atual: %s', tonumber(someData.level)) or "Sem restrição de nível.",
                                                        icon = "user",
                                                        onSelect = function()
                                                            local level = lib.inputDialog(args.craft_name, {
                                                                { type = 'number', label = locales.item_level, description = locales.desc_add_8, default = someData.level, required = true },
                                                            })
                                                            if not level then return lib.showContext('edit_options_items') end
                                                            TriggerServerEvent("forge-crafting:UpdateItems", args.craft_id, someData.item, level[1], "level")
                                                        end,
                                                    },
                                                }
                                            })
                                            lib.showContext('edit_options_items')
                                        end,
                                        arrow = true,
                                    }
                                end
                                lib.registerContext({
                                    id = 'items_listiii',
                                    title = locales.list_itemsa,
                                    menu = "edit_opcije",
                                    options = options
                                })
                                lib.showContext('items_listiii')
                            end
                        end, args.craft_id)
                        --             end,
                        --         },
                        --     }
                        -- })
                        -- lib.showContext('items_menu_configuration')
                    end,
                    description = locales.desc_items_options
                },
                {
                    title = locales.job_obtions,
                    icon = "fa-solid fa-pen-nib",
                    onSelect = function()
                        QT.TriggerCallback('forge-crafting:CheckOptionsEnable', function(jobRequire)
                            local listJobs = ""
                            if not jobRequire then
                                for i = 1, #args.jobs do
                                    local someData = args.jobs[i]
                                    listJobs = string.format('%s 🟢%s \n', listJobs, someData)
                                end
                            end
    
                            lib.registerContext({
                                id = 'jobs_editss',
                                title = args.craft_name,
                                menu = 'edit_opcije',
                                options = {
                                    {
                                        title = locales.add_jobs,
                                        icon = "briefcase",
                                        onSelect = function()
                                            local jobTable = {}
                                            QT.TriggerCallback('forge-crafting:fetchJobs', function(jobs)
                                                for _, job in pairs(jobs) do
                                                    insert(jobTable, { label = job.label, value = job.value })
                                                end
    
                                                local jobsetlist = lib.inputDialog(locales.select_job, {
                                                    { type = 'multi-select', label = locales.choose, options = jobTable }
                                                })
    
                                                if not jobsetlist then return lib.showContext('jobs_editss') end
    
                                                TriggerServerEvent('forge-crafting:ChangeJobs', args.craft_id, jobsetlist[1])
                                                Wait(100)
                                                TriggerServerEvent("forge-crafting:Update")
                                                TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                            end)
                                        end,
                                        description = locales.desc_adding_jobs
                                    },
                                    {
                                        title = locales.remove_job_requirement,
                                        icon = "fa-solid fa-folder-closed",
                                        onSelect = function()
                                            TriggerServerEvent("forge-crafting:RemoveRequirement", args.craft_id)
                                            Wait(100)
                                            TriggerServerEvent("forge-crafting:Update")
                                            TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                        end,
                                        description = jobRequire and locales.desc_job_req or
                                            string.format('Remover os grupos: \n %s', listJobs),
                                        disabled = jobRequire,
                                    },
                                }
                            })
                            lib.showContext('jobs_editss')
                        end, args.craft_id)
                    end,
                    description = locales.desc_remove_jobs_jobs
                },
                {
                    title = locales.edit_position,
                    icon = "location-dot",
                    onSelect = function()
                        QT.TriggerCallback("forge-crafting:GetEntityModel", function(model)
                            updateModelPosition(model, args)
                        end, args.craft_id)
                    end,
                    description = locales.desc_edit_position
                },
                {
                    title = locales.teleport_to_coords,
                    icon = "fa-brands fa-google-play",
                    onSelect = function()
                        QT.TriggerCallback("forge-crafting:GetEntityCoords", function(coords)
                            SetEntityCoords(cache.ped, vec3(coords.x, coords.y, coords.z))
                            SetEntityHeading(cache.ped, coords.w)
                            notification(locales.main_title, locales.teleport_success .. args.craft_name, types.info)
                            TriggerEvent("forge-crafting:OpenEditFunctions", args)
                        end, args.craft_id)
                    end,
                    description = locales.desc_edit_position
                },
                --   {
                --     title = locales.blip_settings,
                --     icon = "fa-solid fa-map",
                --     onSelect = function()
                --         local blip = lib.inputDialog(locales.blip_creation, {
                --             { type = 'number', label = locales.blip_sprite, required = true, max = 883, min = 0 },
                --             { type = 'number', label = locales.blip_colour, required = true, max = 85, min = 0 },
                --             { type = 'input', label = locales.blip_scale,  required = true },
                --             { type = 'input',  label = locales.blip_label,  required = true, default = "BLIP NAME", icon = "signature" },
                --         })
                --         if not blip then return end
                --         local blipce = { sprite = blip[1], colour = blip[2], scale = tonumber(blip[3]), blip_label = blip[4] }
                --             TriggerServerEvent("forge-crafting:UpdateBlip", blipce, args.craft_id, args.craft_name)
                --             Wait(100)
                --             TriggerServerEvent("forge-crafting:Update")
                --     end,
                --     description = locales.desc_blipsettings
                --   },
                {
                    title = locales.delete_crafttable,
                    icon = "trash",
                    iconColor = 'red',
                    onSelect = function()
                        local warning = lib.alertDialog({
                            header = locales.automaticmessage,
                            content = locales.sure_delete .. args.craft_name .. "?",
                            centered = true,
                            cancel = true
                        })
                        if warning == "confirm" then
                            TriggerServerEvent("forge-crafting:DeleteTable", args.craft_id, args.craft_name)
                            Wait(100)
                            TriggerServerEvent("forge-crafting:Update")
                            TriggerEvent('forge-crafting:EditMenu')
                        else
                            TriggerEvent("forge-crafting:OpenEditFunctions", args)
                            notification(locales.main_title, locales.deleting_cancelation, types.error)
                        end
                    end,
                    description = locales.desc_deleting
                },
                {
                    title = locales.target_event,
                    icon = "fa-solid fa-bolt",
                    description = (locales.desc_targetevent):format(args.targetable and "Ativado" or "Desativado"),
                    onSelect = function()
                        local options = {
                            { label = "Sim", value = true },
                            { label = "Não", value = false },
                        }
                        local input = lib.inputDialog(locales.target_event, {
                            { type = 'select', label = locales.target_event, options = options, default = args.targetable or false },
                        })
                        if input == nil then return end
                        TriggerServerEvent("forge-crafting:UpdateTargetable", input[1], args.craft_id)
                        Wait(100)
                        TriggerServerEvent("forge-crafting:Update")
                        TriggerEvent('forge-crafting:EditMenu')
                    end,
                },
    
            }
        })
    
        lib.showContext('edit_opcije')
    end)
end)

function updateModelPosition(model, args)
    local heading = 0
    local obj
    local created = false

    lib.requestModel(model)
    CreateThread(function()
        while true do
            ---@diagnostic disable-next-line: need-check-nil
            -- local hit, coords, entity = raycast(100.0)
            local hit, entity, coords = lib.raycast.cam(1, 4)

            if not created then
                created = true
                obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
                SetEntityCollision(obj, false, true)
            end
            lib.showTextUI(table.concat(locales.help))
            if IsControlPressed(0, 174) then
                heading += 1.5
            end

            if IsControlPressed(0, 175) then
                heading -= 1.5
            end

            -- se apertar o Backspace
            if IsDisabledControlPressed(0, 177) then
                DeleteObject(obj)
                Wait(100)
                lib.hideTextUI()
                TriggerEvent('forge-crafting:OpenEditFunctions', args)
                break
            end

            if IsDisabledControlPressed(0, 176) then
                local new_position = vector4(coords.x, coords.y, coords.z, heading)
                TriggerServerEvent("forge-crafting:UpdatePosition", new_position, args.craft_id, args.craft_name)
                DeleteObject(obj)
                Wait(100)
                TriggerServerEvent("forge-crafting:Update")
                lib.hideTextUI()
                TriggerEvent('forge-crafting:OpenEditFunctions', args)
                break
            end

            local pedPos = GetEntityCoords(cache.ped)
            local distance = #(coords - pedPos)

            SetEntityCoords(obj, coords.x, coords.y, coords.z)
            SetEntityHeading(obj, heading)
            Wait(0)
        end
    end)
    collectgarbage("collect")
end

function createRecipe(numRecipe)
    local recipetable = {}
    for i = 1, numRecipe do
        local recipeInput = lib.inputDialog(locales.recipeitem .. ' (' .. i .. '/' .. numRecipe .. ')', {
            { type = 'select', label = locales.item,       description = locales.desc_add_1, options = GetBaseItems(), required = true, searchable = true },
            { type = 'input',  label = locales.item_label, description = locales.desc_add_2, required = true },
            { type = 'number', label = locales.how_much,   description = desc_how_much,      required = true },
        })
        if not recipeInput then return end
        insert(recipetable, { item = recipeInput[1], label = recipeInput[2], amount = recipeInput[3] })
    end
    return recipetable
end

AddEventHandler("forge-crafting:CreateMenu", function()
    QT.TriggerCallback('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then return end
        local input = lib.inputDialog(locales.creation_menu, {
            { type = 'input',    label = locales.table_name, placeholder = locales.desc_tablename, required = true, icon = "signature" },
            { type = 'input',    label = locales.prop,       default = locales.desc_prop,          required = true, icon = "fa-brands fa-creative-commons-nd" },
            { type = "checkbox", label = locales.job,        checked = false },
            { type = "checkbox", label = locales.blip,       checked = false,                      disabled = true },
        })
        if not input then return TriggerEvent('forge-crafting:EditMenu') end
    
        QT.TriggerCallback("forge-crafting:TableExist", function(exist)
            if exist then return notification(locales.main_title, locales.already_exist, types.error) end
    
            local blip_data
            local jobData
    
            local function CreateBlip()
                local blip = lib.inputDialog(locales.blip_creation, {
                    { type = 'number', label = locales.blip_sprite, required = true, max = 883,          min = 0 },
                    { type = 'number', label = locales.blip_colour, required = true, max = 85,           min = 0 },
                    { type = 'input',  label = locales.blip_scale,  required = true },
                    { type = 'input',  label = locales.blip_label,  required = true, default = input[1], icon = "signature" },
                })
                if not blip then return end
                local blip_data = { sprite = blip[1], colour = blip[2], scale = tonumber(blip[3]), blip_label = blip[4] }
                return blip_data
            end
    
            if input[4] then
                local pedcoords = GetEntityCoords(cache.ped)
                local enableblip = CreateBlip()
                blip_data = {
                    sprite = enableblip.sprite,
                    colour = enableblip.colour,
                    scale = enableblip.scale,
                    blip_label = enableblip.blip_label
                }
            end
    
            local function CreateJob(callback)
                local jobTable = {}
                QT.TriggerCallback('forge-crafting:fetchJobs', function(jobs)
                    for _, job in pairs(jobs) do
                        insert(jobTable, { label = job.label, value = job.value })
                    end
    
                    local jobsetlist = lib.inputDialog(locales.select_job, {
                        { type = 'multi-select', label = locales.choose, options = jobTable }
                    })
    
                    if not jobsetlist then return end
                    local jobsa = jobsetlist[1]
                    jobData = jobsa
                    callback()
                end)
            end
    
            local jobSelectionDone = false
    
            if input[3] then
                CreateJob(function()
                    jobSelectionDone = true
                end)
            else
                jobSelectionDone = true
            end
    
            local heading = 0
            local obj
            local created = false
    
            lib.requestModel(input[2])
            CreateThread(function()
                while true do
                    if jobSelectionDone then
                        ---@diagnostic disable-next-line: need-check-nil
                        -- local hit, coords, entity = raycast(100.0)
                        local hit, entity, coords = lib.raycast.cam(1, 4)
    
                        if not created then
                            created = true
                            obj = CreateObject(input[2], coords.x, coords.y, coords.z, false, false, false)
                            SetEntityCollision(obj, false, true)
                        end
                        lib.showTextUI(table.concat(locales.help))
                        if IsControlPressed(0, 174) then
                            heading += 1.5
                        end
    
                        if IsControlPressed(0, 175) then
                            heading -= 1.5
                        end
    
                        -- se apertar o Backspace
                        if IsDisabledControlPressed(0, 177) then
                            DeleteObject(obj)
                            Wait(100)
                            lib.hideTextUI()
                            TriggerEvent('forge-crafting:EditMenu')
                            break
                        end
    
                        if IsDisabledControlPressed(0, 176) then
                            local newData = {
                                craft_name = input[1],
                                prop = input[2],
                                jobrequire = input[3],
                                requireblip = input[4],
                                blip = blip_data,
                                jobs = jobData,
                                propcoords = vector3(coords.x, coords.y, coords.z),
                                heading = heading,
                                jobenable = input[3],
                                blipenable = input[4]
                            }
                            TriggerServerEvent("forge-crafting:CreateWorkShop", newData)
                            DeleteObject(obj)
                            notification(locales.main_title, locales.success_created, types.success)
                            Wait(100)
                            TriggerServerEvent("forge-crafting:Update")
                            TriggerEvent('forge-crafting:EditMenu')
                            lib.hideTextUI()
                            break
                        end
    
                        local pedPos = GetEntityCoords(cache.ped)
                        local distance = #(coords - pedPos)
    
                        SetEntityCoords(obj, coords.x, coords.y, coords.z)
                        SetEntityHeading(obj, heading)
                    end
                    Wait(0)
                end
            end)
    
            collectgarbage("collect")
        end, input[1])
    end)
end)

function GetBaseItems()
    local items = {}
    for k, v in pairs(exports.ox_inventory:Items()) do
        items[#items + 1] = {
            value = k,
            label = string.format('%s (%s)', v.label, k)
        }
    end
    return items
end
