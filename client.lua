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


function CraftMenu(id, name, coords, objectid, offset, entity)
    pr_lib.callback.trigger('forge-crafting:fetchItemsFromId', function(result)
        if not result then return end

        local playerLevel = getCraftingLevel()
        local formattedItems = {}

        for i = 1, #result do
            local someData = result[i]
            local recipeList = {}

            for _, item in ipairs(someData.recipe or {}) do
                local ownedCount = 0
                if pr_lib.inventory and pr_lib.inventory.GetItemCount then
                    ownedCount = pr_lib.inventory.GetItemCount(nil, item.item) or 0
                end

                recipeList[#recipeList + 1] = {
                    item = item.item,
                    label = item.label or item.item,
                    amount = tonumber(item.amount) or 1,
                    owned = ownedCount,
                    currentAmount = ownedCount
                }
            end

            formattedItems[#formattedItems + 1] = {
                item = someData.item,
                item_label = someData.item_label or someData.item,
                time = tonumber(someData.time) or 5,
                amount = tonumber(someData.amount) or 1,
                level = tonumber(someData.level) or 0,
                recipe = recipeList,
                anim = someData.anim,
                model = someData.model
            }
        end

        local benchPayload = {
            id = id,
            name = name,
            coords = coords,
            objectid = objectid,
            offset = offset,
        }

        SendNUIMessage({
            action = 'open',
            bench = benchPayload,
            items = formattedItems,
            playerLevel = playerLevel,
            imagePath = Config.ImagePath
        })

        SetNuiFocus(true, true)
    end, id)
end

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    toggleCam(false)
    if DoesEntityExist(CRAFTABLE_OBJ) then
        DeleteObject(CRAFTABLE_OBJ)
    end
    cb({ ok = true })
end)

RegisterNUICallback('craft', function(data, cb)
    SetNuiFocus(false, false)
    toggleCam(false)
    if DoesEntityExist(CRAFTABLE_OBJ) then
        DeleteObject(CRAFTABLE_OBJ)
    end

    if data and data.craft_item then
        TriggerEvent("forge-crafting:CraftCertainItem", data)
    end

    cb({ ok = true })
end)

local cachedWorkshops = {}

local function getNormalizedJobAndGang()
    local currentJob = pr_lib.framework and pr_lib.framework.GetPlayerJob and pr_lib.framework.GetPlayerJob()
    local currentGang = pr_lib.framework and pr_lib.framework.GetPlayerGang and pr_lib.framework.GetPlayerGang()

    local jobName = type(currentJob) == "table" and (currentJob.name or currentJob.id) or tostring(currentJob or "")
    local gangName = type(currentGang) == "table" and (currentGang.name or currentGang.id) or tostring(currentGang or "")

    return jobName, gangName
end

local function hasPermissionForBench(jobsList, jobenb)
    if not jobenb or not jobsList or #jobsList == 0 then
        return true
    end

    local jobName, gangName = getNormalizedJobAndGang()
    for _, item in ipairs(jobsList) do
        local required = type(item) == "table" and (item.value or item.name) or tostring(item)
        if required == jobName or required == gangName then
            return true
        end
    end

    return false
end

local function RefreshBlips(data)
    if data then
        cachedWorkshops = data
    end

    for i = 1, #Blips do
        if DoesBlipExist(Blips[i]) then
            RemoveBlip(Blips[i])
        end
    end
    Blips = {}

    for _, v in pairs(cachedWorkshops or {}) do
        if v.blipenb and v.blipdata and v.coords then
            if hasPermissionForBench(v.jobs, v.jobenb) then
                BlipCreation(v.blipdata, v.coords)
            end
        end
    end
end

local function CleanupWorldEntities()
    for i = 1, #objects do
        local entity = objects[i]
        if DoesEntityExist(entity) then
            if pr_lib.target and pr_lib.target.removeLocalEntity then
                pr_lib.target.removeLocalEntity(entity)
            end
            SetEntityAsMissionEntity(entity, false, true)
            DeleteObject(entity)
        end
    end
    objects = {}
end

local function CreateTables()
    pr_lib.callback.trigger('forge-crafting:fetchTables', function(data)
        if not data then return end
        cachedWorkshops = data
        RefreshBlips(data)

        local streaming = pr_lib.fivem and pr_lib.fivem.streaming

        for k, v in pairs(data) do
            local modelHash = type(v.model) == "string" and joaat(v.model) or v.model
            local loaded = false

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

            if loaded and v.coords then
                local propobj = CreateObjectNoOffset(modelHash, v.coords.x, v.coords.y, v.coords.z, false, true, false)

                if streaming and streaming.releaseModel then
                    streaming.releaseModel(modelHash)
                else
                    SetModelAsNoLongerNeeded(modelHash)
                end

                if DoesEntityExist(propobj) then
                    SetEntityHeading(propobj, v.coords.w or 0.0)
                    FreezeEntityPosition(propobj, true)
                    SetEntityInvincible(propobj, true)
                    SetEntityAsMissionEntity(propobj, true, true)
                    objects[#objects + 1] = propobj

                    local targetOptions = {
                        {
                            name = 'table_' .. v.id,
                            label = string.format('%s %s', locales.enter_craftable, v.name),
                            icon = "fa-solid fa-hammer",
                            distance = 2.5,
                            canInteract = function()
                                if isBusy then return false end
                                return hasPermissionForBench(v.jobs, v.jobenb)
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
            end
        end
    end)
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(500)
    CreateTables()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    Wait(500)
    RefreshBlips()
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function()
    Wait(500)
    RefreshBlips()
end)

RegisterNetEvent('esx:setJob', function()
    Wait(500)
    RefreshBlips()
end)

RegisterNetEvent("forge-crafting:Sync", function()
    CleanupWorldEntities()
    RefreshBlips({})
    CreateTables()
end)

AddEventHandler("onResourceStop", function(res)
    if GetCurrentResourceName() ~= res then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    CleanupWorldEntities()

    for i = 1, #Blips do
        if DoesBlipExist(Blips[i]) then
            RemoveBlip(Blips[i])
        end
    end
    Blips = {}

    if DoesEntityExist(CRAFTABLE_OBJ) then
        DeleteObject(CRAFTABLE_OBJ)
    end
    toggleCam(false)
end)

AddEventHandler("forge-crafting:CraftCertainItem", function(data)
    local craftId = data.craft_id
    local itemName = data.craft_item

    pr_lib.callback.trigger("forge-crafting:StartCraft", function(success, message, craftData)
        if not success then
            toggleCam(false)
            if DoesEntityExist(CRAFTABLE_OBJ) then DeleteObject(CRAFTABLE_OBJ) end
            if pr_lib.notifications and pr_lib.notifications.Notify then
                pr_lib.notifications.Notify({
                    title = locales.main_title or "Crafting",
                    description = message or locales.cannot_craft,
                    type = "error"
                })
            end
            return
        end

        isBusy = true
        toggleCam(false)

        local ped = PlayerPedId()
        local animDict = 'mini@repair'
        local animClip = 'fixing_a_ped'
        local animOption = (craftData and craftData.anim) or data.anim

        if animOption and animOption ~= "" then
            if exports.scully_emotemenu then
                exports.scully_emotemenu:playEmoteByCommand(animOption, 0)
            else
                RequestAnimDict(animDict)
                local timeout = GetGameTimer() + 2000
                while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(10) end
                if HasAnimDictLoaded(animDict) then
                    TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, 1, 0, false, false, false)
                end
            end
        else
            RequestAnimDict(animDict)
            local timeout = GetGameTimer() + 2000
            while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(10) end
            if HasAnimDictLoaded(animDict) then
                TaskPlayAnim(ped, animDict, animClip, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
        end

        local duration = ((craftData and craftData.time) or (data.time or 5)) * 1000
        local itemLabel = (craftData and craftData.item_label) or (data.item_label or itemName)
        local progressOptions = {
            duration = duration,
            label = locales.craftingg .. itemLabel,
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
            pr_lib.callback.trigger("forge-crafting:FinishCraft", function(finished, finishMsg)
                if finished then
                    PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
                else
                    if pr_lib.notifications and pr_lib.notifications.Notify then
                        pr_lib.notifications.Notify({
                            title = locales.main_title or "Crafting",
                            description = finishMsg or "Erro ao concluir a fabricação.",
                            type = "error"
                        })
                    end
                end
            end)
        else
            TriggerServerEvent("forge-crafting:CancelCraft")
        end

        if DoesEntityExist(CRAFTABLE_OBJ) then
            DeleteObject(CRAFTABLE_OBJ)
        end
    end, craftId, itemName)
end)
