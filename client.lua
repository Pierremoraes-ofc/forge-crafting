-- Client lifecycle, world entity management, and crafting interaction via pr_bridge

local objects = {}
local targetEntities = {}
local isBusy = false
local Blips = {}
local TABLE_CAM, CRAFTABLE_OBJ

local function getCraftingLevel()
    local skillName = (Config.SkillsSystem and Config.SkillsSystem.skillName) or Config.CraftingSkill or 'crafting'

    -- 1. Consultar export configurado pelo usuário em Config.SkillsSystem.getCurrentSkill (Client-side)
    if Config.SkillsSystem and Config.SkillsSystem.enabled and type(Config.SkillsSystem.getCurrentSkill) == 'function' then
        local ok, data = pcall(Config.SkillsSystem.getCurrentSkill, nil, skillName)
        if ok and data ~= nil then
            if type(data) == 'table' then
                local lvl = tonumber(data.level or data.currentLevel or data.lvl)
                local xp = tonumber(data.xp or data.currentXP or data.experience)
                if not lvl and xp then
                    return Config.GetLevelFromXP and Config.GetLevelFromXP(xp) or 1
                end
                return lvl or 1
            elseif type(data) == 'number' then
                if data > 100 and not (Config.Levels and Config.Levels[data]) then
                    return Config.GetLevelFromXP and Config.GetLevelFromXP(data) or 1
                end
                return data
            elseif type(data) == 'string' then
                if data:lower() == 'maestria' then return 999999 end
                return tonumber(data) or 1
            end
        end
    end

    -- 2. Fallback: forge-reputation
    local resource = Config.ReputationResource or 'forge-reputation'
    if GetResourceState(resource) == 'started' then
        local ok, level = pcall(function()
            return exports[resource]:getCurrentLevel(skillName)
        end)
        if ok and level ~= nil then
            if type(level) == 'string' and level:lower() == 'maestria' then
                return 999999
            end
            return tonumber(level) or 1
        end
    end

    return 1
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


local ITEM_ALIASES = {
    ["ferro"] = "iron",
    ["iron"] = "ferro",
    ["metal"] = "metalscrap",
    ["metalscrap"] = "metal",
    ["sucata"] = "metalscrap",
    ["scrap"] = "metalscrap",
    ["scrapmetal"] = "metalscrap",
    ["ouro"] = "gold",
    ["cobre"] = "copper",
    ["aluminio"] = "aluminum",
    ["aluminum"] = "aluminio",
    ["plastico"] = "plastic",
    ["borracha"] = "rubber",
    ["vidro"] = "glass",
    ["aco"] = "steel",
    ["madeira"] = "wood",
}

local function getClientItemCount(itemName)
    if not itemName then return 0 end
    local searchName = string.lower(tostring(itemName))

    -- 1. Leitura direta dos itens do jogador via ox_inventory (GetPlayerItems)
    if exports.ox_inventory and exports.ox_inventory.GetPlayerItems then
        local ok, items = pcall(function() return exports.ox_inventory:GetPlayerItems() end)
        if ok and type(items) == "table" then
            local total = 0
            for _, slotData in pairs(items) do
                if type(slotData) == "table" then
                    local sName = slotData.name and string.lower(tostring(slotData.name))
                    local sLabel = slotData.label and string.lower(tostring(slotData.label))
                    if sName == searchName or (sLabel and sLabel == searchName) then
                        total = total + (tonumber(slotData.count or slotData.amount) or 1)
                    end
                end
            end
            if total > 0 then return total end

            -- Verificar aliases
            local alias = ITEM_ALIASES[searchName]
            if alias then
                for _, slotData in pairs(items) do
                    if type(slotData) == "table" then
                        local sName = slotData.name and string.lower(tostring(slotData.name))
                        local sLabel = slotData.label and string.lower(tostring(slotData.label))
                        if sName == alias or (sLabel and sLabel == alias) then
                            total = total + (tonumber(slotData.count or slotData.amount) or 1)
                        end
                    end
                end
                if total > 0 then return total end
            end
        end
    end

    -- 2. Tentativa via export Search('count', ...)
    if exports.ox_inventory and exports.ox_inventory.Search then
        local ok, c = pcall(function() return exports.ox_inventory:Search('count', itemName) end)
        if ok and c and tonumber(c) and tonumber(c) > 0 then return tonumber(c) end

        local alias = ITEM_ALIASES[searchName]
        if alias then
            local okA, cA = pcall(function() return exports.ox_inventory:Search('count', alias) end)
            if okA and cA and tonumber(cA) and tonumber(cA) > 0 then return tonumber(cA) end
        end
    end

    -- 3. Tentativa via export GetItem com returnsCount=true
    if exports.ox_inventory and exports.ox_inventory.GetItem then
        local ok, c = pcall(function() return exports.ox_inventory:GetItem(itemName, nil, true) end)
        if ok and c and tonumber(c) and tonumber(c) > 0 then return tonumber(c) end

        local alias = ITEM_ALIASES[searchName]
        if alias then
            local okA, cA = pcall(function() return exports.ox_inventory:GetItem(alias, nil, true) end)
            if okA and cA and tonumber(cA) and tonumber(cA) > 0 then return tonumber(cA) end
        end
    end

    -- 4. Tentativa via pr_lib.inventory
    if pr_lib and pr_lib.inventory and pr_lib.inventory.GetItemCount then
        local ok, c = pcall(function() return pr_lib.inventory.GetItemCount(itemName) end)
        if ok and c and tonumber(c) and tonumber(c) > 0 then return tonumber(c) end

        local alias = ITEM_ALIASES[searchName]
        if alias then
            local okA, cA = pcall(function() return pr_lib.inventory.GetItemCount(alias) end)
            if okA and cA and tonumber(cA) and tonumber(cA) > 0 then return tonumber(cA) end
        end
    end

    return 0
end

local function resolveItemImageUrl(itemName)
    if not itemName or itemName == "" then return "" end
    if itemName:find("^http") then return itemName end

    local baseName = tostring(itemName):gsub("%.%w+$", "")
    local searchLower = string.lower(baseName)

    -- Mapear aliases conhecidos (ex: ferro -> iron, metal -> metalscrap, sucata -> metalscrap)
    local mapped = ITEM_ALIASES[searchLower]
    if mapped then
        baseName = mapped
    end

    return "images/" .. baseName .. ".png"
end

local function resolveItemLabel(itemName, fallbackLabel)
    if fallbackLabel and fallbackLabel ~= "" and fallbackLabel ~= itemName then
        return fallbackLabel
    end
    if pr_lib and pr_lib.inventory and pr_lib.inventory.Items then
        local ok, itemData = pcall(pr_lib.inventory.Items, itemName)
        if ok and itemData and (itemData.label or itemData.name) then
            return itemData.label or itemData.name
        end
    end
    return fallbackLabel or itemName
end

local function getClientPlayerJob()
    if pr_lib and pr_lib.player and pr_lib.player.getJob then
        local job = pr_lib.player.getJob()
        if job then return job end
    end
    if pr_lib and pr_lib.framework and pr_lib.framework.GetPlayerJob then
        local job = pr_lib.framework.GetPlayerJob()
        if job then return job end
    end
    return nil
end

local function getClientPlayerGang()
    if pr_lib and pr_lib.player and pr_lib.player.getGang then
        local gang = pr_lib.player.getGang()
        if gang then return gang end
    end
    if pr_lib and pr_lib.framework and pr_lib.framework.GetPlayerGang then
        local gang = pr_lib.framework.GetPlayerGang()
        if gang then return gang end
    end
    return nil
end

function hasPermissionForBench(jobsData, jobenb)
    if not jobenb or not jobsData then return true, nil end
    if type(jobsData) ~= "table" then return true, nil end

    local playerJob = getClientPlayerJob()
    local playerGang = getClientPlayerGang()

    local jobName = type(playerJob) == "table" and (playerJob.name or playerJob.id) or tostring(playerJob or "")
    local gangName = type(playerGang) == "table" and (playerGang.name or playerGang.id) or tostring(playerGang or "")

    -- 1. Estrutura detalhada de cargo/facção (auth_type = 'job' ou 'gang')
    if jobsData.auth_type or jobsData.name then
        local authType = jobsData.auth_type or 'job'
        local targetName = tostring(jobsData.name or jobsData.value or '')
        local targetLabel = tostring(jobsData.label or targetName)
        local minGrade = tonumber(jobsData.min_grade or jobsData.grade) or 0
        local requireDuty = (jobsData.require_duty == true) or (jobsData.duty == true)

        if authType == 'job' then
            if jobName ~= targetName then
                return false, string.format("Acesso restrito ao emprego: %s.", targetLabel)
            end

            if requireDuty then
                local onDuty = false
                if type(playerJob) == "table" then
                    if playerJob.onduty ~= nil then onDuty = playerJob.onduty end
                    if playerJob.onDuty ~= nil then onDuty = playerJob.onDuty end
                    if playerJob.duty ~= nil then onDuty = playerJob.duty end
                end
                if not onDuty then
                    return false, "Você precisa estar em serviço (Duty ativo) para utilizar esta bancada!"
                end
            end

            if minGrade > 0 then
                local pGrade = 0
                if type(playerJob) == "table" then
                    if type(playerJob.grade) == "table" then
                        pGrade = tonumber(playerJob.grade.level or playerJob.grade.grade) or 0
                    else
                        pGrade = tonumber(playerJob.grade) or 0
                    end
                end
                if pGrade < minGrade then
                    return false, string.format("Cargo insuficiente no emprego! Exigido cargo nível %d ou superior (Seu cargo atual: %d).", minGrade, pGrade)
                end
            end

            return true, nil
        elseif authType == 'gang' then
            if gangName ~= targetName then
                return false, string.format("Acesso restrito à facção/gangue: %s.", targetLabel)
            end

            if minGrade > 0 then
                local gGrade = 0
                if type(playerGang) == "table" then
                    if type(playerGang.grade) == "table" then
                        gGrade = tonumber(playerGang.grade.level or playerGang.grade.grade) or 0
                    else
                        gGrade = tonumber(playerGang.grade) or 0
                    end
                end
                if gGrade < minGrade then
                    return false, string.format("Cargo insuficiente na facção! Exigido cargo nível %d ou superior (Seu cargo atual: %d).", minGrade, gGrade)
                end
            end

            return true, nil
        end
    end

    -- 2. Compatibilidade com formato legado de array de empregos
    if #jobsData > 0 then
        for _, j in ipairs(jobsData) do
            local required = type(j) == "table" and (j.value or j.name) or tostring(j)
            if required == jobName or required == gangName then
                return true, nil
            end
        end
        return false, "Você não possui o emprego ou facção autorizada para esta bancada."
    end

    return true, nil
end

function CraftMenu(idOrBench, name, coords, objectid, offset, entity)
    local benchData = nil
    local benchId = nil
    local benchEntity = nil

    if type(idOrBench) == "table" then
        benchData = idOrBench
        benchId = benchData.id
        benchEntity = name -- quando chamado CraftMenu(v, propobj)
    else
        benchId = idOrBench
        benchEntity = entity -- quando chamado CraftMenu(id, name, coords, objectid, offset, entity)
        for _, b in ipairs(cachedWorkshops or {}) do
            if tonumber(b.id) == tonumber(benchId) then
                benchData = b
                break
            end
        end
    end

    if benchData and benchData.jobenb then
        local allowed, reason = hasPermissionForBench(benchData.jobs, benchData.jobenb)
        if not allowed then
            if pr_lib.notifications and pr_lib.notifications.Notify then
                pr_lib.notifications.Notify({
                    title = locales.main_title or "Crafting",
                    description = reason or "Você não possui permissão para acessar esta bancada.",
                    type = "error"
                })
            end
            return
        end
    end

    pr_lib.callback.trigger('forge-crafting:fetchItemsFromId', function(result, srvLevel, srvXP)
        if not result or type(result) ~= "table" then result = {} end

        local playerLevel = tonumber(srvLevel) or getCraftingLevel()
        local formattedItems = {}

        for i = 1, #result do
            local someData = result[i]
            local recipeList = {}

            for _, item in ipairs(someData.recipe or {}) do
                local serverCount = tonumber(item.owned or item.currentAmount) or 0
                local clientCount = getClientItemCount(item.item)
                local ownedCount = math.max(serverCount, clientCount)
                local ingLabel = (item.label and item.label ~= "") and item.label or resolveItemLabel(item.item, item.label)
                local ingImage = (item.image and item.image ~= "") and item.image or resolveItemImageUrl(item.item)

                print(string.format('[forge-crafting] Ingrediente: %s -> Server: %d, Client: %d => Final: %d', tostring(item.item), serverCount, clientCount, ownedCount))

                recipeList[#recipeList + 1] = {
                    item = item.item,
                    label = ingLabel,
                    amount = tonumber(item.amount) or 1,
                    owned = ownedCount,
                    currentAmount = ownedCount,
                    image = ingImage
                }
            end

            local prodLabel = (someData.item_label and someData.item_label ~= "") and someData.item_label or resolveItemLabel(someData.item, someData.item_label)
            local prodImage = (someData.image and someData.image ~= "") and someData.image or resolveItemImageUrl(someData.image or someData.item)

            formattedItems[#formattedItems + 1] = {
                item = someData.item,
                item_label = prodLabel,
                time = tonumber(someData.time) or 5,
                amount = tonumber(someData.amount) or 1,
                level = tonumber(someData.level) or 0,
                recipe = recipeList,
                anim = someData.anim,
                model = someData.model,
                image = prodImage
            }
        end

        local currentBench = benchData
        if not currentBench then
            for _, b in ipairs(cachedWorkshops or {}) do
                if tonumber(b.id) == tonumber(benchId) then
                    currentBench = b
                    break
                end
            end
        end

        if not currentBench then
            currentBench = {
                id = benchId,
                name = name,
                coords = coords,
                objectid = objectid,
                offset = offset,
            }
        end

        -- Se a bancada não possui bench_model ou está incompleto, aplicar fallback
        if not currentBench.bench_model or not currentBench.bench_model.center_offset then
            currentBench.bench_model = {
                slug = 'default',
                label = 'Workbench',
                model = currentBench.model or 'xm3_prop_xm3_bench_04b',
                center_offset = { x = -0.05, y = 0.0, z = 0.805, w = 0.0 },
                scale = 1.0,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = { x = -0.85, y = 0.0, z = 0.25 },
                cam_offset = { x = -0.15, y = 0.0, z = 0.65 }
            }
        end

        -- Anexar a entidade física se existir e atualizar coords e heading precisos do mundo
        if benchEntity and DoesEntityExist(benchEntity) then
            currentBench.entity = benchEntity
            local eCoords = GetEntityCoords(benchEntity)
            local eHeading = GetEntityHeading(benchEntity)
            currentBench.heading = eHeading
            currentBench.coords = vector4(eCoords.x, eCoords.y, eCoords.z, eHeading)
        end

        -- Inicia a sessão interativa da DUI na bancada (câmera, animação de trabalho e mouse)
        StartBenchDuiSession(currentBench, formattedItems, playerLevel)
    end, benchId)
end

RegisterNUICallback('close', function(data, cb)
    StopBenchDuiSession()
    toggleCam(false)
    if DoesEntityExist(CRAFTABLE_OBJ) then
        DeleteObject(CRAFTABLE_OBJ)
    end
    cb({ ok = true })
end)

RegisterNUICallback('craft', function(data, cb)
    StopBenchDuiSession()
    toggleCam(false)
    if DoesEntityExist(CRAFTABLE_OBJ) then
        DeleteObject(CRAFTABLE_OBJ)
    end

    if data and data.craft_item then
        TriggerEvent("forge-crafting:CraftCertainItem", data)
    end

    cb({ ok = true })
end)

RegisterNUICallback('openSearchInput', function(data, cb)
    cb({ ok = true })

    CreateThread(function()
        local isWeapons = data and data.mode == 'weapons'
        local dialogTitle = isWeapons and "Buscar Armas" or "Buscar Receita"
        local dialogPlaceholder = isWeapons and "Digite o nome da arma..." or "Digite o nome da receita..."

        local input = nil
        if exports.ox_lib and exports.ox_lib.inputDialog then
            local dialog = exports.ox_lib:inputDialog(dialogTitle, {
                { type = "input", label = isWeapons and "Filtrar armas" or "Filtrar receitas", placeholder = dialogPlaceholder, icon = "search" }
            })
            if dialog and dialog[1] then
                input = tostring(dialog[1])
            else
                input = ""
            end
        elseif pr_lib and pr_lib.input then
            local res = pr_lib.input({
                title = dialogTitle,
                type = "text",
                placeholder = dialogPlaceholder
            })
            input = res and tostring(res) or ""
        else
            DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 30)
            while UpdateOnscreenKeyboard() == 0 do
                Wait(0)
            end
            if UpdateOnscreenKeyboard() == 1 then
                input = GetOnscreenKeyboardResult() or ""
            else
                input = ""
            end
        end

        if input ~= nil and SendActiveDuiMessage then
            SendActiveDuiMessage({
                action = 'search',
                mode = isWeapons and 'weapons' or 'recipes',
                query = input
            })
        end
    end)
end)

-- =====================================================
--  NUI Callbacks - Sistema de Upgrades de Armas
-- =====================================================

RegisterNUICallback('getUpgradeData', function(data, cb)
    pr_lib.callback.trigger('forge-crafting:getUpgradeData', function(result)
        result = result or { weapons = {}, attachments = {}, tints = {} }

        -- A compatibilidade nativa do GTA só existe no cliente. Enriquecer os
        -- itens aqui permite à DUI desabilitar acessórios que não encaixam na
        -- arma selecionada antes de qualquer alteração de inventário.
        for _, attachment in ipairs(result.attachments or {}) do
            attachment.compatibleWeapons = {}
            attachment.componentHashes = {}
            for _, weapon in ipairs(result.weapons or {}) do
                local componentHash = WeaponComponentsConfig.ResolveComponentHash(weapon.name, attachment.name)
                if componentHash then
                    local slotKey = tostring(weapon.slot)
                    attachment.compatibleWeapons[slotKey] = true
                    attachment.componentHashes[slotKey] = componentHash
                end
            end
        end

        cb(result)
    end)
end)

RegisterNUICallback('selectUpgradeWeapon', function(data, cb)
    if data and data.weapon then
        SpawnUpgradeWeaponObject(data.weapon)
    else
        ClearUpgradeWeaponObject()
    end
    cb({ ok = true })
end)

RegisterNUICallback('clearUpgradeWeapon', function(data, cb)
    ClearUpgradeWeaponObject()
    cb({ ok = true })
end)

RegisterNUICallback('installWeaponComponent', function(data, cb)
    if not data or not data.weaponSlot or not data.weaponName or not data.componentItem then
        cb({ ok = false, message = "Dados inválidos." })
        return
    end

    local validatedHash = WeaponComponentsConfig.ResolveComponentHash(data.weaponName, data.componentItem)
    if not validatedHash then
        cb({ ok = false, message = "Este componente não é compatível com a arma selecionada." })
        return
    end

    pr_lib.callback.trigger('forge-crafting:installWeaponComponent', function(success, metaOrErr, compHash)
        if success then
            if UpdateCurrentUpgradeWeaponComponents then
                UpdateCurrentUpgradeWeaponComponents(metaOrErr)
            elseif compHash then
                AttachComponentToCurrentUpgradeWeapon(compHash)
            end
            PlaySoundFrontend(-1, "WEAPON_ATTACHMENT_EQUIP", "HUD_AMMO_SHOP_SOUNDSET", 1)
            cb({ ok = true, metadata = metaOrErr })
        else
            PlaySoundFrontend(-1, "ERROR", "HUD_AMMO_SHOP_SOUNDSET", 1)
            cb({ ok = false, message = metaOrErr or "Falha ao instalar componente." })
        end
    end, data.weaponSlot, data.componentItem, validatedHash, data.weaponName)
end)

RegisterNUICallback('toggleExplodedView', function(data, cb)
    if not ToggleUpgradeWeaponExplodedView then
        cb({ ok = false, expanded = false })
        return
    end
    local ok, expanded = ToggleUpgradeWeaponExplodedView()
    cb({ ok = ok == true, expanded = expanded == true })
end)

RegisterNUICallback('removeWeaponComponent', function(data, cb)
    if not data or not data.weaponSlot or not data.componentName then
        cb({ ok = false, message = "Dados inválidos." })
        return
    end

    pr_lib.callback.trigger('forge-crafting:removeWeaponComponent', function(success, metaOrErr, compHash)
        if success then
            if UpdateCurrentUpgradeWeaponComponents then
                UpdateCurrentUpgradeWeaponComponents(metaOrErr)
            elseif compHash then
                RemoveComponentFromCurrentUpgradeWeapon(compHash)
            end
            PlaySoundFrontend(-1, "WEAPON_ATTACHMENT_UNEQUIP", "HUD_AMMO_SHOP_SOUNDSET", 1)
            cb({ ok = true, metadata = metaOrErr })
        else
            PlaySoundFrontend(-1, "ERROR", "HUD_AMMO_SHOP_SOUNDSET", 1)
            cb({ ok = false, message = metaOrErr or "Falha ao remover componente." })
        end
    end, data.weaponSlot, data.componentName)
end)

RegisterNUICallback('setWeaponTint', function(data, cb)
    if not data or not data.weaponSlot or data.tintIndex == nil then
        cb({ ok = false, message = "Dados inválidos." })
        return
    end

    pr_lib.callback.trigger('forge-crafting:setWeaponTint', function(success, tintOrErr)
        if success then
            SetCurrentUpgradeWeaponTint(data.tintIndex)
            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            cb({ ok = true, tint = tintOrErr })
        else
            cb({ ok = false, message = tintOrErr or "Falha ao aplicar pintura." })
        end
    end, data.weaponSlot, data.tintIndex)
end)

cachedWorkshops = {}

local function getNormalizedJobAndGang()
    local currentJob = pr_lib.framework and pr_lib.framework.GetPlayerJob and pr_lib.framework.GetPlayerJob()
    local currentGang = pr_lib.framework and pr_lib.framework.GetPlayerGang and pr_lib.framework.GetPlayerGang()

    local jobName = type(currentJob) == "table" and (currentJob.name or currentJob.id) or tostring(currentJob or "")
    local gangName = type(currentGang) == "table" and (currentGang.name or currentGang.id) or tostring(currentGang or "")

    return jobName, gangName, currentJob, currentGang
end

local function hasPermissionForBench(jobsList, jobenb)
    if not jobenb or not jobsList then
        return true, nil
    end

    local jobName, gangName, currentJob, currentGang = getNormalizedJobAndGang()

    -- 1. Objeto rico de autorização (auth_type = 'job' ou 'gang')
    if type(jobsList) == "table" and (jobsList.auth_type or jobsList.name) then
        local authType = jobsList.auth_type or 'job'
        local targetName = tostring(jobsList.name or jobsList.value or '')
        local targetLabel = tostring(jobsList.label or targetName)
        local minGrade = tonumber(jobsList.min_grade or jobsList.grade) or 0
        local requireDuty = (jobsList.require_duty == true) or (jobsList.duty == true)

        if authType == 'job' then
            if jobName ~= targetName then
                return false, string.format("Acesso restrito ao emprego: %s.", targetLabel)
            end

            if requireDuty then
                local onDuty = false
                if type(currentJob) == "table" then
                    if currentJob.onduty ~= nil then onDuty = currentJob.onduty end
                    if currentJob.onDuty ~= nil then onDuty = currentJob.onDuty end
                    if currentJob.duty ~= nil then onDuty = currentJob.duty end
                end
                if not onDuty then
                    return false, "Você precisa estar em serviço (Duty ativo) para utilizar esta bancada!"
                end
            end

            if minGrade > 0 then
                local pGrade = 0
                if type(currentJob) == "table" then
                    if type(currentJob.grade) == "table" then
                        pGrade = tonumber(currentJob.grade.level or currentJob.grade.grade) or 0
                    else
                        pGrade = tonumber(currentJob.grade) or 0
                    end
                end
                if pGrade < minGrade then
                    return false, string.format("Cargo insuficiente no emprego (Exigido: %d | Seu: %d).", minGrade, pGrade)
                end
            end

            return true, nil
        elseif authType == 'gang' then
            if gangName ~= targetName then
                return false, string.format("Acesso restrito à facção: %s.", targetLabel)
            end

            if minGrade > 0 then
                local gGrade = 0
                if type(currentGang) == "table" then
                    if type(currentGang.grade) == "table" then
                        gGrade = tonumber(currentGang.grade.level or currentGang.grade.grade) or 0
                    else
                        gGrade = tonumber(currentGang.grade) or 0
                    end
                end
                if gGrade < minGrade then
                    return false, string.format("Cargo insuficiente na facção (Exigido: %d | Seu: %d).", minGrade, gGrade)
                end
            end

            return true, nil
        end
    end

    -- 2. Tabela sequencial legada: { 'police', 'sheriff' } ou { { value = 'police' } }
    if type(jobsList) == "table" and #jobsList > 0 then
        for _, item in ipairs(jobsList) do
            local required = type(item) == "table" and (item.value or item.name) or tostring(item)
            if required == jobName or required == gangName then
                return true, nil
            end
        end
        return false, "Acesso restrito: você não pertence ao grupo autorizado."
    end

    return true, nil
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
        workshops = data
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
                    local propHeading = tonumber(v.heading) or (v.coords and (tonumber(v.coords.w) or tonumber(v.coords.heading))) or 0.0
                    SetEntityHeading(propobj, propHeading)
                    FreezeEntityPosition(propobj, true)
                    SetEntityInvincible(propobj, true)
                    SetEntityAsMissionEntity(propobj, true, true)
                    objects[#objects + 1] = propobj

                    v.entity = propobj
                    v.heading = propHeading

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
                                CraftMenu(v, propobj)
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
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
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

-- =====================================================
--  Exports e Eventos Client de Habilidade e Nível
-- =====================================================

exports('GetPlayerLevel', function()
    return getCraftingLevel()
end)

exports('GetCraftingLevel', function()
    return getCraftingLevel()
end)

exports('GetPlayerXP', function()
    if Config.GetXPForLevel then
        local lvl = getCraftingLevel()
        return Config.GetXPForLevel(lvl)
    end
    return 0
end)

RegisterNetEvent('forge-crafting:updatePlayerLevel', function(newLevel, newXP)
    if SendDuiMessageToActiveSession then
        SendDuiMessageToActiveSession({
            action = 'updatePlayerLevel',
            playerLevel = newLevel,
            playerXP = newXP
        })
    end
end)
