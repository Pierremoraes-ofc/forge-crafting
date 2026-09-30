-- Client lifecycle, world entity management, and crafting interaction via pr_bridge

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

local function BlipCreation(v, g)
    local blip = AddBlipForCoord(vector3(g.x, g.y, g.z))
    SetBlipSprite(blip, v.sprite)
    SetBlipScale(blip, v.scale)
    SetBlipColour(blip, v.colour)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(tostring(v.blip_label))
    EndTextCommandSetBlipName(blip)
    Blips[#Blips + 1] = blip
end

local function toggleCam(toggle, obj, offset)
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
        FreezeEntityPosition(PlayerPedId(), true)
        TABLE_CAM = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamActive(TABLE_CAM, true)
        RenderScriptCams(true, true, 250, 1, 0)
        SetCamCoord(TABLE_CAM, coords.x, coords.y, coords.z + 0.1 + (offset or 1.1))
        SetCamRot(TABLE_CAM, 0.0, 0.0, GetEntityHeading(obj))
    end
end

local function previewCraftable(data)
    local modelHash = type(data.model) == "string" and joaat(data.model) or data.model
    if modelHash and IsModelInCdimage(modelHash) then
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end

        local offset = data.offset and data.offset or 1.1
        toggleCam(true, data.entity or objects[data.objectid], offset)
        if data.entity then
            data.coords = GetOffsetFromEntityInWorldCoords(data.entity, 0, 0, 0)
        end

        CRAFTABLE_OBJ = CreateObject(modelHash, data.coords.x, data.coords.y, data.coords.z + offset, true, false, true)
        SetEntityHeading(CRAFTABLE_OBJ, GetEntityHeading(PlayerPedId()) + 180)
        SetEntityInvincible(CRAFTABLE_OBJ, true)
        SetModelAsNoLongerNeeded(modelHash)

        SetEntityDrawOutline(CRAFTABLE_OBJ, true)
        SetEntityDrawOutlineColor(255, 255, 255, 30)
        SetEntityDrawOutlineShader(1)

        PlaySoundFrontend(-1, "Reset_Prop_Position", "DLC_Dmod_Prop_Editor_Sounds", 1)

        CreateThread(function()
            while DoesEntityExist(CRAFTABLE_OBJ) do
                local heading = GetEntityHeading(CRAFTABLE_OBJ) + 0.5
                SetEntityHeading(CRAFTABLE_OBJ, heading)
                Wait(0)
            end
        end)
    end

    local secondaryOptions = {}
    local craftable = true

    for _, item in ipairs(data.recipe) do
        local amount = item.amount
        local label = item.label
        local inventoryAmount = pr_lib.inventory and pr_lib.inventory.GetItemCount and pr_lib.inventory.GetItemCount(nil, item.item) or 0
        local imageURL = "nui://" .. Config.ImagePath .. item.item .. ".png"
        local levelNeeded = tonumber(data.level) or 0
        local playerLevel = getCraftingLevel()

        craftable = craftable and (inventoryAmount >= amount) and (levelNeeded <= playerLevel)

        local description
        if levelNeeded > 0 then
            description = string.format('Possui: %s  \nExperiência Necessária: %s', inventoryAmount, levelNeeded)
        else
            description = string.format('Possui: %s', inventoryAmount)
        end

        secondaryOptions[#secondaryOptions + 1] = {
            title = string.format('%sx %s', amount, label),
            icon = imageURL,
            description = description,
            disabled = not craftable,
        }
    end

    if craftable then
        if DoesEntityExist(CRAFTABLE_OBJ) then SetEntityDrawOutlineColor(0, 255, 0, 100) end
    else
        if DoesEntityExist(CRAFTABLE_OBJ) then SetEntityDrawOutlineColor(255, 0, 0, 100) end
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

    local contextFn = pr_lib.RegisterContext or (pr_lib.interface and pr_lib.interface.RegisterContext) or (pr_lib.ox and pr_lib.ox.registerContext)
    local showContextFn = pr_lib.showContext or (pr_lib.interface and pr_lib.interface.showContext) or (pr_lib.ox and pr_lib.ox.showContext)

    if contextFn and showContextFn then
        contextFn({
            id = 'forge-crafting:previewCraftable',
            title = data.item_label,
            menu = 'crafting' .. data.menu_id,
            onBack = function()
                toggleCam(false)
                if DoesEntityExist(CRAFTABLE_OBJ) then DeleteObject(CRAFTABLE_OBJ) end
            end,
            canClose = false,
            options = secondaryOptions
        })
        showContextFn('forge-crafting:previewCraftable')
    end
end

function CraftMenu(id, name, coords, objectid, offset, entity)
    pr_lib.callback.trigger('forge-crafting:fetchItemsFromId', function(result)
        if not result then return end

        local options = {}
        for i = 1, #result do
            local someData = result[i]
            local itemMetadata = {}

            for _, item in ipairs(someData.recipe or {}) do
                itemMetadata[#itemMetadata + 1] = { label = item.label, value = item.amount }
            end

            options[#options + 1] = {
                title = someData.item_label,
                description = locales.items_recipe_desc .. (someData.time or 0) .. "s",
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

        local contextFn = pr_lib.RegisterContext or (pr_lib.interface and pr_lib.interface.RegisterContext) or (pr_lib.ox and pr_lib.ox.registerContext)
        local showContextFn = pr_lib.showContext or (pr_lib.interface and pr_lib.interface.showContext) or (pr_lib.ox and pr_lib.ox.showContext)

        if contextFn and showContextFn then
            contextFn({
                id = 'crafting' .. id,
                title = name,
                options = options,
                onExit = function()
                    toggleCam(false)
                end
            })
            showContextFn('crafting' .. id)
        end
    end, id)
end

local function CreateTables()
    pr_lib.callback.trigger('forge-crafting:fetchTables', function(data)
        if not data then return end

        local playerJob = pr_lib.framework and pr_lib.framework.GetPlayerJob and pr_lib.framework.GetPlayerJob()
        local playerGang = pr_lib.framework and pr_lib.framework.GetPlayerGang and pr_lib.framework.GetPlayerGang()

        for k, v in pairs(data) do
            if v.blipenb then
                if v.jobenb then
                    local loop = v.jobs or {}
                    for _, item in ipairs(loop) do
                        if item == playerJob or item == playerGang then
                            BlipCreation(v.blipdata, v.coords)
                            break
                        end
                    end
                else
                    BlipCreation(v.blipdata, v.coords)
                end
            end

            local modelHash = type(v.model) == "string" and joaat(v.model) or v.model
            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do
                Wait(10)
            end

            local propobj = CreateObject(modelHash, v.coords.x, v.coords.y, v.coords.z, false, true, false)
            SetEntityHeading(propobj, v.coords.w)
            FreezeEntityPosition(propobj, true)
            SetEntityInvincible(propobj, true)
            SetModelAsNoLongerNeeded(modelHash)
            PlaceObjectOnGroundProperly(propobj)
            objects[#objects + 1] = propobj

            local targetOptions = {
                {
                    name = 'table_' .. v.id,
                    label = string.format('%s %s', locales.enter_craftable, v.name),
                    icon = "fa-solid fa-hammer",
                    distance = 3.0,
                    canInteract = function()
                        if isBusy then return false end
                        if v.jobenb then
                            local loop = v.jobs or {}
                            for _, item in ipairs(loop) do
                                local currentJob = pr_lib.framework and pr_lib.framework.GetPlayerJob and pr_lib.framework.GetPlayerJob()
                                local currentGang = pr_lib.framework and pr_lib.framework.GetPlayerGang and pr_lib.framework.GetPlayerGang()
                                if item == currentJob or item == currentGang then
                                    return true
                                end
                            end
                            return false
                        end
                        return true
                    end,
                    onSelect = function(entityData)
                        PlaySoundFrontend(-1, "Place_Prop_Success", "DLC_Dmod_Prop_Editor_Sounds", 1)
                        CraftMenu(v.id, v.name, v.coords, k, v.offset, propobj)
                    end,
                }
            }

            if pr_lib.target and pr_lib.target.addLocalEntity then
                pr_lib.target.addLocalEntity(propobj, targetOptions)
            end
        end
    end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500)
    CreateTables()
end)

RegisterNetEvent("forge-crafting:Sync", function()
    for i = 1, #objects do
        if DoesEntityExist(objects[i]) then
            if pr_lib.target and pr_lib.target.removeLocalEntity then
                pr_lib.target.removeLocalEntity(objects[i])
            end
            DeleteObject(objects[i])
        end
    end
    objects = {}

    for i = 1, #Blips do
        RemoveBlip(Blips[i])
    end
    Blips = {}

    CreateTables()
end)

AddEventHandler("onResourceStop", function(res)
    if GetCurrentResourceName() ~= res then return end

    for i = 1, #objects do
        if DoesEntityExist(objects[i]) then
            if pr_lib.target and pr_lib.target.removeLocalEntity then
                pr_lib.target.removeLocalEntity(objects[i])
            end
            DeleteObject(objects[i])
        end
    end
    objects = {}

    for i = 1, #Blips do
        RemoveBlip(Blips[i])
    end
    Blips = {}

    if DoesEntityExist(CRAFTABLE_OBJ) then
        DeleteObject(CRAFTABLE_OBJ)
    end
    toggleCam(false)
end)

AddEventHandler("forge-crafting:CraftCertainItem", function(data)
    pr_lib.callback.trigger("forge-crafting:CanCraftItem", function(canCraft)
        if canCraft then
            isBusy = true
            toggleCam(false)

            local ped = PlayerPedId()
            if tostring(data.anim) == "" or not data.anim then
                local animDict = 'mini@repair'
                RequestAnimDict(animDict)
                while not HasAnimDictLoaded(animDict) do Wait(10) end
                TaskPlayAnim(ped, animDict, 'fixing_a_ped', 8.0, -8.0, -1, 2, 0, false, false, false)
            else
                if exports.scully_emotemenu then
                    exports.scully_emotemenu:playEmoteByCommand(data.anim, 0)
                end
            end

            local duration = (data.time or 5) * 1000
            local progressOptions = {
                duration = duration,
                label = locales.craftingg .. data.item_label,
                useWhileDead = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                    mouse = false
                }
            }

            local progressFn = pr_lib.progressBar or (pr_lib.ox and pr_lib.ox.progressBar)
            local craftSuccess = false
            if progressFn then
                craftSuccess = progressFn(progressOptions)
            else
                Wait(duration)
                craftSuccess = true
            end

            isBusy = false
            ClearPedTasksImmediately(ped)

            if craftSuccess then
                for _, v in pairs(data.recipe or {}) do
                    TriggerServerEvent("forge-crafting:ItemInterval", "remove", v.item, v.amount)
                end
                TriggerServerEvent("forge-crafting:ItemInterval", "add", data.craft_item, data.amount)

                if pr_lib.notifications and pr_lib.notifications.Notify then
                    pr_lib.notifications.Notify({
                        title = locales.main_title,
                        description = locales.successfull_crafted .. data.item_label .. locales.in_amount_of .. data.amount,
                        type = "success"
                    })
                end

                if DoesEntityExist(CRAFTABLE_OBJ) then DeleteObject(CRAFTABLE_OBJ) end
                PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            else
                if pr_lib.notifications and pr_lib.notifications.Notify then
                    pr_lib.notifications.Notify({
                        title = locales.main_title,
                        description = locales.canceled_crafting_proccess,
                        type = "error"
                    })
                end
                toggleCam(false)
                if DoesEntityExist(CRAFTABLE_OBJ) then DeleteObject(CRAFTABLE_OBJ) end
            end
        else
            if pr_lib.notifications and pr_lib.notifications.Notify then
                pr_lib.notifications.Notify({
                    title = locales.main_title,
                    description = locales.cannot_craft,
                    type = "error"
                })
            end
            toggleCam(false)
            if DoesEntityExist(CRAFTABLE_OBJ) then DeleteObject(CRAFTABLE_OBJ) end
        end
    end, data.recipe)
end)
