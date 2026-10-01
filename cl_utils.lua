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

if Config.Pfx and Config.Pfx ~= '' then
    registerCraftingCommand(Config.Pfx .. Config.CreateTableCommand, "forge-crafting:CreateMenu")
    registerCraftingCommand(Config.Pfx .. Config.EditMenuCommand, "forge-crafting:EditMenu")
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
                                            level = adder[8] and tonumber(adder[8]) or nil
                                        }
                                        TriggerServerEvent("forge-crafting:AddItemCrafting", data)
                                        notify(locales.main_title, locales.success_add_item, "success")
                                        Wait(100)
                                        TriggerEvent('forge-crafting:OpenEditFunctions', args)
                                    end, args.craft_id)
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
                                    pr_lib.callback.trigger('forge-crafting:fetchJobs', function(jobs)
                                        local jobTable = {}
                                        for _, job in pairs(jobs or {}) do
                                            jobTable[#jobTable + 1] = { label = job.label, value = job.value }
                                        end

                                        local jobsetlist = pr_lib.inputDialog(locales.select_job, {
                                            { type = 'multi-select', label = locales.choose, options = jobTable, required = true }
                                        })

                                        if not jobsetlist then return pr_lib.showContext('jobs_editss') end
                                        local jobsa = jobsetlist[1]
                                        TriggerServerEvent("forge-crafting:ChangeJobs", args.craft_id, jobsa)
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
        local input = pr_lib.inputDialog(locales.creation_menu, {
            { type = 'input', label = locales.table_name, placeholder = locales.desc_tablename, required = true, icon = "signature" },
            { type = 'input', label = locales.prop, default = locales.desc_prop, required = true, icon = "fa-brands fa-creative-commons-nd" },
            { type = "checkbox", label = locales.job, checked = false },
            { type = "checkbox", label = locales.blip, checked = false, disabled = true },
        })
        if not input then return TriggerEvent('forge-crafting:EditMenu') end

        pr_lib.callback.trigger("forge-crafting:TableExist", function(exist)
            if exist then return notify(locales.main_title, locales.already_exist, "error") end

            local blip_data
            local jobData

            local function CreateBlip()
                local blip = pr_lib.inputDialog(locales.blip_creation, {
                    { type = 'number', label = locales.blip_sprite, required = true, max = 883, min = 0 },
                    { type = 'number', label = locales.blip_colour, required = true, max = 85, min = 0 },
                    { type = 'input', label = locales.blip_scale, required = true },
                    { type = 'input', label = locales.blip_label, required = true, default = input[1], icon = "signature" },
                })
                if not blip then return end
                return { sprite = blip[1], colour = blip[2], scale = tonumber(blip[3]), blip_label = blip[4] }
            end

            if input[4] then
                blip_data = CreateBlip()
            end

            local function CreateJob(callback)
                local jobTable = {}
                pr_lib.callback.trigger('forge-crafting:fetchJobs', function(jobs)
                    for _, job in pairs(jobs or {}) do
                        jobTable[#jobTable + 1] = { label = job.label, value = job.value }
                    end

                    local jobsetlist = pr_lib.inputDialog(locales.select_job, {
                        { type = 'multi-select', label = locales.choose, options = jobTable }
                    })

                    if not jobsetlist then return end
                    jobData = jobsetlist[1]
                    callback()
                end)
            end

            local function startBenchPlacement()
                placeBenchWithGizmo(input[2], nil, nil, "Posicionar Nova Bancada: " .. tostring(input[1]), function(coords, heading, confirmed)
                    if confirmed and coords then
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
                        notify(locales.main_title, locales.success_created, "success")
                        Wait(100)
                        TriggerServerEvent("forge-crafting:Update")
                        TriggerEvent('forge-crafting:EditMenu')
                    else
                        TriggerEvent('forge-crafting:EditMenu')
                    end
                end)
            end

            if input[3] then
                CreateJob(function()
                    startBenchPlacement()
                end)
            else
                startBenchPlacement()
            end
        end, input[1])
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
