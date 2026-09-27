local objects = {}
local targetEntities = {}
local isBusy = false
local Blips = {}

local TABLE_CAM, CRAFTABLE_OBJ

local function getCraftingLevel()
    local resource = Config.ReputationResource or 'forge-reputation'
    if GetResourceState(resource) ~= 'started' then return 0 end

    local ok, level = pcall(function()
        return exports[resource]:getCurrentLevel(Config.CraftingSkill or 'crafting')
    end)

    if not ok then return 0 end

    if type(level) == 'string' and level:lower() == 'maestria' then
        return 999999
    end

    return tonumber(level) or 0
end

AddEventHandler("onResourceStop", function(res)
    if GetCurrentResourceName() == res then
        for i = 1, #objects do
            DeleteObject(objects[i])
        end

        for i = 1, #targetEntities do
            exports.ox_target:removeModel(targetEntities[i])
        end

        DeleteObject(CRAFTABLE_OBJ)
    end
end)

local function CreateTables()
    QT.TriggerCallback('forge-crafting:fetchTables', function(data)
        if data then
            for k, v in pairs(data) do
                if v.blipenb then
                    if v.jobenb then
                        local loop = v.jobs
                        for _, item in ipairs(loop) do
                            if QT.getjob() == item then
                                BlipCreation(v.blipdata, v.coords)
                            end
                        end
                    else
                        BlipCreation(v.blipdata, v.coords)
                    end
                end

                propobj = CreateObject(v.model, vector3(v.coords.x, v.coords.y, v.coords.z), false, true)
                SetEntityHeading(propobj, v.coords.w)
                FreezeEntityPosition(propobj, true)
                SetEntityInvincible(propobj, true)
                insert(objects, propobj)
                SetModelAsNoLongerNeeded(v.model)
                PlaceObjectOnGroundProperly(propobj)

                if Config.Target == "ox_target" then
                    if not v.targetable then
                        exports.ox_target:addLocalEntity(propobj, {
                            {
                                name = 'table_' .. v.id,
                                label = string.format('%s %s', locales.enter_craftable, v.name),
                                icon = "fa-solid fa-hammer",
                                distance = 3,
                                canInteract = function()
                                    if v.jobenb then
                                        local loop = v.jobs
                                        for _, item in ipairs(loop) do
                                            if item == QT.getjob() or item == QT.getgang() then
                                                if not isBusy then
                                                    return true
                                                else
                                                    return false
                                                end
                                            end
                                        end
                                    else
                                        if not isBusy then
                                            return true
                                        else
                                            return false
                                        end
                                    end
                                end,
                                onSelect = function(data)
                                    PlaySoundFrontend(-1, "Place_Prop_Success", "DLC_Dmod_Prop_Editor_Sounds", 1)

                                    CraftMenu(v.id, v.name, v.coords, k, v.offset)
                                end,
                                -- onExit = toggleCam(false)
                            }
                        })
                    else
                        -- verificar se na tabela targetEntities existe um v.model igual
                        -- for i = 1, #targetEntities do
                        --     if targetEntities[i] == v.model then
                        --         return
                        --     end
                        -- end

                        targetEntities[#targetEntities + 1] = v.model
                        exports.ox_target:addModel(v.model, {
                            {
                                name = 'table_' .. v.id,
                                label = string.format('%s %s', locales.enter_craftable, v.name),
                                icon = "fa-solid fa-hammer",
                                distance = 3,
                                canInteract = function()
                                    if v.jobenb then
                                        local loop = v.jobs
                                        for _, item in ipairs(loop) do
                                            if item == QT.getjob() or item == QT.getgang() then
                                                if not isBusy then
                                                    return true
                                                else
                                                    return false
                                                end
                                            end
                                        end
                                    else
                                        if not isBusy then
                                            return true
                                        else
                                            return false
                                        end
                                    end
                                end,
                                onSelect = function(data)
                                    PlaySoundFrontend(-1, "Place_Prop_Success", "DLC_Dmod_Prop_Editor_Sounds", 1)
                                    CraftMenu(v.id, v.name, data.coords, k, v.offset, data.entity)
                                end,
                            }
                        })
                    end
                        
                elseif Config.Target == "qb-target" then ---@deprecated NÃO USEM, SEM SUPORTE
                    exports['qb-target']:AddTargetEntity(propobj, {
                        options = {
                            {
                                action = function()
                                    CraftMenu(v.id, v.name)
                                end,
                                icon = "fa-solid fa-hammer",
                                label = locales.enter_craftable,
                                canInteract = function()
                                    if v.jobenb then
                                        local loop = v.jobs
                                        for _, item in ipairs(loop) do
                                            if item == QT.getjob() then
                                                if not isBusy then
                                                    return true
                                                else
                                                    return false
                                                end
                                            end
                                        end
                                    else
                                        if not isBusy then
                                            return true
                                        else
                                            return false
                                        end
                                    end
                                end,
                            }
                        },
                        distance = 3.0
                    })
                end
            end
        end
    end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    Wait(500) -- # because of auto insert from bridge/server/insert.lua its just because on first resource start to load everything fine :) enjoy
    CreateTables()
end)

RegisterNetEvent("forge-crafting:Sync")
AddEventHandler("forge-crafting:Sync", function()
    for i = 1, #objects do
        DeleteObject(objects[i])
    end
    objects = {}
    for i = 1, #targetEntities do
        exports.ox_target:removeModel(targetEntities[i])
    end
    targetEntities = {}
    CreateTables()
    for i = 1, #Blips do
        RemoveBlip(Blips[i])
    end
end)

CraftMenu = function(id, name, coords, objectid, offset, entity)
    QT.TriggerCallback('forge-crafting:fetchItemsFromId', function(result)
        if result then
            local options = {}
            for i = 1, #result do
                local someData = result[i]
                local itemMetadata = {}

                for _, item in ipairs(someData.recipe) do
                    insert(itemMetadata, { label = item.label, value = item.amount })
                end
                options[#options + 1] = {
                    title = someData.item_label,
                    description = locales.items_recipe_desc .. someData.time .. "s",
                    icon = "nui://" .. Config.ImagePath .. someData.item .. ".png",
                    onSelect = previewCraftable,
                    arrow = true,
                    metadata = itemMetadata,
                    args = { 
                        menu_id = id, 
                        anim = someData.anim, 
                        model = someData.model, 
                        craft_item = someData.item, 
                        item_label = someData.item_label, 
                        time = someData.time, 
                        amount = someData.amount, 
                        recipe = someData.recipe, 
                        coords = coords, 
                        objectid = objectid, 
                        offset = offset,
                        level = someData.level,
                        entity = entity
                    }
                }
            end

            lib.registerContext({
                id = 'crafting' .. id,
                title = name,
                options = options,
                onExit = function()
                    toggleCam(false)
                end
            })

            lib.showContext('crafting' .. id)
        end
    end, id)
end

local function ZoneCheck(v)
    local ply = GetEntityCoords(cache.ped)
    local dist = #(ply - vector3(v.x, v.y, v.z))
    if dist <= 3.0 then
        return true
    else
        return false
    end
end

AddEventHandler("forge-crafting:CraftCertainItem", function(data)
    QT.TriggerCallback("forge-crafting:CanCraftItem", function(canCraft)
        if canCraft then
            isBusy = true
            toggleCam(false)
            -- verificar se o texto da animação existe ou não está vazio
            if tostring(data.anim) == "" or not data.anim then
                lib.requestAnimDict('mini@repair', 100)
                TaskPlayAnim(cache.ped, 'mini@repair', 'fixing_a_ped', 8.0, -8.0, -1, 2, 0, false, false, false)
            else
                -- utiizando scully_emotemenu para animações mais simples
                exports.scully_emotemenu:playEmoteByCommand(data.anim, 0)
            end
            local craft_process = progress(locales.craftingg .. data.item_label, data.time, "default")
            if craft_process then
                isBusy = false
                ClearPedTasksImmediately(cache.ped)
                for k, v in pairs(data.recipe) do
                    TriggerServerEvent("forge-crafting:ItemInterval", "remove", v.item, v.amount)
                end
                TriggerServerEvent("forge-crafting:ItemInterval", "add", data.craft_item, data.amount)
                notification(locales.main_title,
                    locales.successfull_crafted .. data.item_label .. locales.in_amount_of .. data.amount, types.success)
                DeleteObject(CRAFTABLE_OBJ)
                PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            else
                isBusy = false
                notification(locales.main_title, locales.canceled_crafting_proccess, types.error)
                ClearPedTasksImmediately(cache.ped)
                toggleCam(false)
                DeleteObject(CRAFTABLE_OBJ)
            end
        else
            notification(locales.main_title, locales.cannot_craft, types.error)
            toggleCam(false)
            DeleteObject(CRAFTABLE_OBJ)
        end
    end, data.recipe)
end)

BlipCreation = function(v, g)
    blip = AddBlipForCoord(vector3(g.x, g.y, g.z))
    SetBlipSprite(blip, v.sprite)
    SetBlipScale(blip, v.scale)
    SetBlipColour(blip, v.colour)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(tostring(v.blip_label))
    EndTextCommandSetBlipName(blip)
    insert(Blips, blip)
end

function toggleCam(toggle, obj, offset)
    if not toggle and DoesCamExist(TABLE_CAM) then
        PlaySoundFrontend(-1, "Zoom_Left", "DLC_HEIST_PLANNING_BOARD_SOUNDS", 1)
        RenderScriptCams(false, true, 250, 1, 0)
        DestroyCam(TABLE_CAM, false)
        FreezeEntityPosition(PlayerPedId(), false)
    elseif toggle and not DoesCamExist(TABLE_CAM) then
        PlaySoundFrontend(-1, "Zoom_In", "DLC_HEIST_PLANNING_BOARD_SOUNDS", 1)
        local coords = GetOffsetFromEntityInWorldCoords(obj, 0, -0.75, 0)
        RenderScriptCams(false, false, 0, 1, 0)
        DestroyCam(TABLE_CAM, false)
        FreezeEntityPosition(cache.ped, true)
        TABLE_CAM = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamActive(TABLE_CAM, true)
        RenderScriptCams(true, true, 250, 1, 0)
        SetCamCoord(TABLE_CAM, coords.x, coords.y, coords.z + 0.1 + offset)
        SetCamRot(TABLE_CAM, 0.0, 0.0, GetEntityHeading(obj))
    end
end

--- Função para pré-visualizar o item fabricável
-- @param data Tabela contendo informações sobre o item a ser fabricado
-- @field model string Modelo do objeto a ser criado
-- @field coords table Coordenadas onde o objeto será criado
-- @field recipe table Lista de itens necessários para a fabricação
-- @field item string Nome do item fabricável
-- @field item_label string Rótulo do item fabricável
-- @field time number Tempo necessário para a fabricação
-- @field amount number Quantidade do item a ser fabricado
-- @field menu_id number ID do menu de fabricação
-- @field objectid number ID do objeto criado
function previewCraftable(data)
    local success, err = pcall(lib.requestModel, data.model)
    if success then
        local offset = data.offset and data.offset or 1.1
        toggleCam(true, data.entity and data.entity or objects[data.objectid], offset)
        if data.entity then
            local coords = GetOffsetFromEntityInWorldCoords(data.entity, 0, 0, 0)
            data.coords = coords
        end

        CRAFTABLE_OBJ = CreateObject(data.model, data.coords.x, data.coords.y, data.coords.z + offset, true, false, true)
        SetEntityHeading(CRAFTABLE_OBJ, GetEntityHeading(cache.ped) + 180)
        SetEntityInvincible(CRAFTABLE_OBJ, true)

        -- Adiciona contorno verde brilhante ao objeto
        SetEntityDrawOutline(CRAFTABLE_OBJ, true)
        SetEntityDrawOutlineColor(255, 255, 255, 30)
        SetEntityDrawOutlineShader(1)

        PlaySoundFrontend(-1, "Reset_Prop_Position", "DLC_Dmod_Prop_Editor_Sounds", 1)

        -- Função para fazer o objeto girar
        Citizen.CreateThread(function()
            while DoesEntityExist(CRAFTABLE_OBJ) do
                local heading = GetEntityHeading(CRAFTABLE_OBJ) + 0.5 -- Ajuste a velocidade da rotação aqui
                SetEntityHeading(CRAFTABLE_OBJ, heading)
                Citizen.Wait(0)                                       -- Tempo de espera entre cada incremento de rotação
            end
        end)
    end

    local requiredItems = ''
    local secondaryOptions = {}
    local craftable = true
    for _, item in ipairs(data.recipe) do
        local amount = item.amount
        local label = item.label
        local inventoryAmount = exports.ox_inventory:GetItemCount(item.item)
        local imageURL = "nui://" .. Config.ImagePath .. item.item .. ".png"
        local levelNeeded = tonumber(data.level) or 0
        local playerLevel = getCraftingLevel()

        craftable = craftable and inventoryAmount >= amount and levelNeeded <= playerLevel
        
        local description
        if levelNeeded > 0 then
            description = string.format('Possui: %s  \nExperiência Necessária: %s', inventoryAmount, levelNeeded)
        else
            description = string.format('Possui: %s', inventoryAmount)
        end

        secondaryOptions[#secondaryOptions + 1] = {
            title = string.format('%sx %s', amount, label),
            icon = imageURL,
            image = imageURL,
            description = description,
            disabled = not craftable,
        }
    end

    if craftable then
        SetEntityDrawOutlineColor(0, 255, 0, 100)
    else
        SetEntityDrawOutlineColor(255, 0, 0, 100)
    end

    secondaryOptions[#secondaryOptions + 1] = {
        title = 'Fabricar',
        arrow = true,
        event = "forge-crafting:CraftCertainItem",
        args = { 
            craft_item = data.craft_item, 
            item_label = data.item_label, 
            time = data.time, 
            amount = data.amount, 
            recipe = data.recipe, 
            coords = data.coords, 
            objectid = data.objectid, 
            anim = data.anim,
            model = data.model,
        },
        disabled = not craftable
    }
    -- if craftable.required_blueprint then
    --     local blueprintOption = {
    --         title = craftable.required_blueprint_label,
    --         icon = 'book',
    --     }
    --     table.insert(secondaryOptions, 1, blueprintOption)
    -- end

    lib.registerContext({
        id = 'forge-crafting:previewCraftable',
        title = data.item_label,
        menu = 'crafting' .. data.menu_id,
        onBack = function()
            toggleCam(false)
            DeleteObject(CRAFTABLE_OBJ)
        end,
        canClose = false,
        options = secondaryOptions
    })

    lib.showContext('forge-crafting:previewCraftable')
end
