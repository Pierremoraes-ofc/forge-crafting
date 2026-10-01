-- Server-side crafting operations, callbacks, and database persistence via pr_lib

local workshops = {}

local function serverNotification(player, title, message, msgType)
    if pr_lib.notifications and pr_lib.notifications.NotifyPlayer then
        pr_lib.notifications.NotifyPlayer(player, {
            title = title or locales.main_title,
            description = message,
            type = msgType or "inform"
        })
    end
end

local function addCraftingSkill(source)
    local resource = Config.ReputationResource or 'forge-reputation'
    if GetResourceState(resource) ~= 'started' then return end

    pcall(function()
        exports[resource]:updateSkill(source, Config.CraftingSkill or 'crafting', Config.CraftingSkillReward or 5)
    end)
end

local activeCraftSessions = {}

local function getBenchById(craft_id)
    craft_id = tonumber(craft_id)
    for _, bench in ipairs(workshops or {}) do
        if tonumber(bench.id) == craft_id then
            return bench
        end
    end
    return nil
end

local function getPlayerLevel(source)
    local resource = Config.ReputationResource or 'forge-reputation'
    if GetResourceState(resource) ~= 'started' then return 0 end
    local ok, level = pcall(function()
        return exports[resource]:getCurrentLevel(source, Config.CraftingSkill or 'crafting')
    end)
    if not ok then return 0 end
    if type(level) == 'string' and level:lower() == 'maestria' then return 999999 end
    return tonumber(level) or 0
end

local function isPlayerAuthorizedForBench(source, bench)
    if not bench.jobenb or not bench.jobs or #bench.jobs == 0 then
        return true
    end

    local playerJob = pr_lib.framework and pr_lib.framework.GetPlayerJob and pr_lib.framework.GetPlayerJob(source)
    local playerGang = pr_lib.framework and pr_lib.framework.GetPlayerGang and pr_lib.framework.GetPlayerGang(source)

    local jobName = type(playerJob) == "table" and (playerJob.name or playerJob.id) or tostring(playerJob or "")
    local gangName = type(playerGang) == "table" and (playerGang.name or playerGang.id) or tostring(playerGang or "")

    for _, j in ipairs(bench.jobs) do
        local required = type(j) == "table" and (j.value or j.name) or tostring(j)
        if required == jobName or required == gangName then
            return true
        end
    end
    return false
end

local function isPlayerAdmin(source)
    if not source or source == 0 then return true end
    if IsPlayerAceAllowed(source, 'admin') then return true end
    if IsPlayerAceAllowed(source, 'crafting') then return true end
    if IsPlayerAceAllowed(source, 'command.' .. tostring(Config.CreateTableCommand or "create")) then return true end
    if IsPlayerAceAllowed(source, 'command.' .. tostring(Config.EditMenuCommand or "edit")) then return true end
    return false
end

local function registerServerAdminCommand(cmd, eventName)
    if not cmd or cmd == "" then return end
    RegisterCommand(cmd, function(source, args)
        if isPlayerAdmin(source) then
            if source > 0 then
                TriggerClientEvent(eventName, source)
            else
                print("[forge-crafting] Comandos administrativos de interface devem ser executados no jogo por um jogador.")
            end
        else
            serverNotification(source, locales.main_title or "Crafting", locales.insufficient_permission or "Você não possui permissão para usar esta função.", "error")
        end
    end, false)
end

registerServerAdminCommand(Config.CreateTableCommand, "forge-crafting:CreateMenu")
registerServerAdminCommand(Config.EditMenuCommand, "forge-crafting:EditMenu")

if Config.Pfx and Config.Pfx ~= "" then
    registerServerAdminCommand(Config.Pfx .. Config.CreateTableCommand, "forge-crafting:CreateMenu")
    registerServerAdminCommand(Config.Pfx .. Config.EditMenuCommand, "forge-crafting:EditMenu")
end

pr_lib.callback.register('forge-crafting:PermisionCheck', function(source)
    if isPlayerAdmin(source) then
        return true
    else
        serverNotification(source, locales.main_title, locales.insufficient_permission, "error")
        return false
    end
end)

pr_lib.callback.register('forge-crafting:fetchJobs', function(source)
    local options = {}

    local jobs = pr_lib.framework.GetFrameworkJobs and pr_lib.framework.GetFrameworkJobs() or {}
    for k, v in pairs(jobs) do
        local label = type(v) == "table" and (v.label or k) or tostring(v)
        if label ~= 'Civil' and label ~= 'unemployed' then
            options[#options + 1] = { label = label, value = k }
        end
    end

    local gangs = pr_lib.framework.GetFrameworkGangs and pr_lib.framework.GetFrameworkGangs() or {}
    for k, v in pairs(gangs) do
        local label = type(v) == "table" and (v.label or k) or tostring(v)
        if label ~= 'Sem gangue' and label ~= 'none' then
            options[#options + 1] = { label = label, value = k }
        end
    end

    return options
end)

RegisterNetEvent('forge-crafting:CreateWorkShop', function(data)
    local crafting = {
        model = data.prop,
        propcoords = vec3(data.propcoords.x, data.propcoords.y, data.propcoords.z),
        heading = data.heading,
        blipenable = data.blipenable,
        jobenable = data.jobenable
    }

    pr_lib.db.insert(
        'INSERT INTO `forge-crafting` (craft_name, crafting, blipdata, jobs) VALUES (?, ?, ?, ?)',
        {
            data.craft_name,
            json.encode(crafting),
            json.encode(data.blip),
            json.encode(data.jobs)
        }
    )

    TriggerEvent("forge-crafting:Update")
end)

pr_lib.callback.register('forge-crafting:TableExist', function(source, name)
    local result = pr_lib.db.single('SELECT craft_id FROM `forge-crafting` WHERE craft_name = ?', { name })
    return result ~= nil
end)

pr_lib.callback.register("forge-crafting:GetList", function(source)
    local result = pr_lib.db.query('SELECT * FROM `forge-crafting`', {})
    if not result then return false end

    local send = {}
    for i = 1, #result do
        local craftData = json.decode(result[i].crafting) or {}
        send[#send + 1] = {
            craft_name = result[i].craft_name,
            craft_id = result[i].craft_id,
            jobs = json.decode(result[i].jobs) or {},
            crafting = craftData,
            offset = craftData.offset and tonumber(craftData.offset) or 1.1,
            targetable = craftData.targetable or false
        }
    end
    return send
end)

pr_lib.callback.register("forge-crafting:GetListItems", function(source, craft_id)
    local result = pr_lib.db.query('SELECT * FROM `forge-crafting-items` WHERE craft_id = ?', { craft_id })
    if not result then return false end

    local send = {}
    for i = 1, #result do
        local someData = result[i]
        send[#send + 1] = {
            craft_id = someData.craft_id,
            item = someData.item,
            item_label = someData.item_label,
            model = someData.model,
            amount = someData.amount,
            anim = someData.anim,
            level = someData.level
        }
    end
    return send
end)

pr_lib.callback.register("forge-crafting:fetchItemsFromId", function(source, craft_id)
    local result = pr_lib.db.query('SELECT * FROM `forge-crafting-items` WHERE craft_id = ?', { craft_id })
    if not result then return false end

    local send = {}
    for i = 1, #result do
        local someData = result[i]
        send[#send + 1] = {
            craft_id = someData.craft_id,
            item = someData.item,
            item_label = someData.item_label,
            recipe = json.decode(someData.recipe) or {},
            amount = someData.amount,
            time = someData.time,
            model = someData.model,
            anim = someData.anim,
            level = someData.level
        }
    end
    return send
end)

RegisterNetEvent("forge-crafting:ChangeName", function(id, newname)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        pr_lib.db.execute('UPDATE `forge-crafting` SET craft_name = ? WHERE craft_id = ?', { newname, id })
    end
end)

RegisterNetEvent("forge-crafting:DeleteTable", function(id, name)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        pr_lib.db.execute('DELETE FROM `forge-crafting` WHERE craft_id = ?', { id })
        pr_lib.db.execute('DELETE FROM `forge-crafting-items` WHERE craft_id = ?', { id })
        serverNotification(src, locales.main_title, locales.sucessfullydeleted .. ' ' .. (name or ""), "success")
        TriggerEvent("forge-crafting:Update")
    end
end)

RegisterNetEvent("forge-crafting:AddItemCrafting", function(data)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        pr_lib.db.insert(
            'INSERT INTO `forge-crafting-items` (craft_id, item, item_label, recipe, time, amount, model, anim, level) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            {
                data.craft_id,
                data.main_item,
                data.item_label,
                json.encode(data.recipe),
                data.time,
                data.amount,
                data.model,
                data.anim,
                data.level
            }
        )
    end
end)

local function loadWorkshops()
    workshops = {}
    local result = pr_lib.db.query('SELECT * FROM `forge-crafting`', {})
    if result and type(result) == "table" then
        for i = 1, #result do
            local craftData = json.decode(result[i].crafting) or {}
            local blipData = json.decode(result[i].blipdata) or {}
            local jobsData = json.decode(result[i].jobs) or {}
            workshops[#workshops + 1] = {
                model = craftData.model,
                id = result[i].craft_id,
                name = result[i].craft_name,
                coords = vector4(craftData.propcoords.x, craftData.propcoords.y, craftData.propcoords.z, craftData.heading or 0.0),
                jobenb = craftData.jobenable,
                blipenb = craftData.blipenable,
                blipdata = blipData,
                jobs = jobsData,
                offset = craftData.offset and tonumber(craftData.offset) or 1.1,
                targetable = craftData.targetable
            }
        end
    end
end

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(200)
        loadWorkshops()
    end
end)

pr_lib.callback.register('forge-crafting:fetchTables', function(source)
    if #workshops == 0 then
        loadWorkshops()
    end
    return workshops
end)

RegisterNetEvent("forge-crafting:Update", function()
    loadWorkshops()
    Wait(50)
    TriggerClientEvent("forge-crafting:Sync", -1)
end)

RegisterNetEvent("forge-crafting:ChangeJobs", function(id, jobs)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
        if row then
            local craftData = json.decode(row.crafting) or {}
            craftData.jobenable = true
            pr_lib.db.execute('UPDATE `forge-crafting` SET jobs = ?, crafting = ? WHERE craft_id = ?', {
                json.encode(jobs),
                json.encode(craftData),
                id
            })
            serverNotification(src, locales.main_title, locales.job_successfully_changed, "success")
            TriggerEvent("forge-crafting:Update")
        end
    end
end)

RegisterNetEvent("forge-crafting:RemoveRequirement", function(id)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
        if row then
            local craftData = json.decode(row.crafting) or {}
            craftData.jobenable = false
            pr_lib.db.execute('UPDATE `forge-crafting` SET jobs = NULL, crafting = ? WHERE craft_id = ?', {
                json.encode(craftData),
                id
            })
            serverNotification(src, locales.main_title, locales.job_requirement_deleted, "success")
            TriggerEvent("forge-crafting:Update")
        end
    end
end)

pr_lib.callback.register("forge-crafting:CheckOptionsEnable", function(source, id)
    local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
    if row then
        local craftData = json.decode(row.crafting) or {}
        return not craftData.jobenable
    end
    return true
end)

pr_lib.callback.register("forge-crafting:CanCraftItem", function(source, recipe)
    local src = source
    local canCraft = true

    for _, data in ipairs(recipe or {}) do
        local count = pr_lib.inventory.GetItemCount and pr_lib.inventory.GetItemCount(src, data.item) or 0
        if count < (data.amount or 1) then
            canCraft = false
            break
        end
    end

    return canCraft
end)

pr_lib.callback.register("forge-crafting:StartCraft", function(source, craft_id, item_name)
    local src = source
    if not pr_lib.framework.GetPlayer(src) then
        return false, "Jogador não identificado.", nil
    end

    if activeCraftSessions[src] then
        return false, "Você já possui uma fabricação em andamento.", nil
    end

    local bench = getBenchById(craft_id)
    if not bench then
        return false, "Bancada de criação não localizada.", nil
    end

    -- 1. Validação de proximidade física
    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local benchCoords = vector3(bench.coords.x, bench.coords.y, bench.coords.z)
    local dist = #(playerCoords - benchCoords)
    if dist > 4.5 then
        return false, locales.distance_behavior or "Você está longe demais da bancada de criação!", nil
    end

    -- 2. Validação de cargos/gangues
    if not isPlayerAuthorizedForBench(src, bench) then
        return false, locales.insufficient_permission or "Você não possui permissão para usar esta bancada.", nil
    end

    -- 3. Carregar receita autoritativa no banco
    local recipeRow = pr_lib.db.single(
        'SELECT * FROM `forge-crafting-items` WHERE craft_id = ? AND item = ?',
        { craft_id, item_name }
    )
    if not recipeRow then
        return false, "Receita não encontrada para esta bancada.", nil
    end

    -- 4. Validação de nível mínimo de maestria
    local requiredLevel = tonumber(recipeRow.level) or 0
    if requiredLevel > 0 then
        local playerLevel = getPlayerLevel(src)
        if playerLevel < requiredLevel then
            return false, string.format("Nível insuficiente de crafting! Exigido: Nível %d (Seu: %d).", requiredLevel, playerLevel), nil
        end
    end

    -- 5. Validação e consumo seguro dos insumos
    local recipe = json.decode(recipeRow.recipe) or {}
    if #recipe == 0 then
        return false, "Esta receita está configurada incorretamente (sem ingredientes).", nil
    end

    for _, ing in ipairs(recipe) do
        local requiredAmount = tonumber(ing.amount) or 1
        local currentCount = pr_lib.inventory.GetItemCount and pr_lib.inventory.GetItemCount(src, ing.item) or 0
        if currentCount < requiredAmount then
            return false, locales.cannot_craft or "Você não possui todos os itens necessários no inventário.", nil
        end
    end

    local consumedList = {}
    for _, ing in ipairs(recipe) do
        local amount = tonumber(ing.amount) or 1
        pr_lib.inventory.RemoveItem(src, ing.item, amount)
        consumedList[#consumedList + 1] = { item = ing.item, amount = amount }
    end

    activeCraftSessions[src] = {
        craft_id = craft_id,
        item = recipeRow.item,
        item_label = recipeRow.item_label or recipeRow.item,
        amount = tonumber(recipeRow.amount) or 1,
        duration = tonumber(recipeRow.time) or 5,
        consumed = consumedList,
        benchCoords = benchCoords,
        startTime = GetGameTimer()
    }

    return true, "Fabricação iniciada.", {
        item = recipeRow.item,
        item_label = recipeRow.item_label or recipeRow.item,
        amount = tonumber(recipeRow.amount) or 1,
        time = tonumber(recipeRow.time) or 5,
        model = recipeRow.model,
        anim = recipeRow.anim,
        level = recipeRow.level
    }
end)

pr_lib.callback.register("forge-crafting:FinishCraft", function(source)
    local src = source
    local session = activeCraftSessions[src]
    if not session then
        return false, "Nenhuma sessão de fabricação ativa."
    end

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local dist = #(playerCoords - session.benchCoords)
    if dist > 4.5 then
        for _, ing in ipairs(session.consumed) do
            pr_lib.inventory.AddItem(src, ing.item, ing.amount)
        end
        activeCraftSessions[src] = nil
        return false, locales.distance_behavior or "Você se afastou demais da bancada! Materiais devolvidos."
    end

    local elapsed = GetGameTimer() - session.startTime
    local expectedMs = (session.duration * 1000) - 1500
    if elapsed < expectedMs then
        for _, ing in ipairs(session.consumed) do
            pr_lib.inventory.AddItem(src, ing.item, ing.amount)
        end
        activeCraftSessions[src] = nil
        return false, "Operação inválida: tempo de fabricação inconsistente."
    end

    pr_lib.inventory.AddItem(src, session.item, session.amount)
    addCraftingSkill(src)

    local successMessage = (locales.successfull_crafted or "Você criou com sucesso ") .. session.item_label .. (locales.in_amount_of or " x") .. session.amount
    serverNotification(src, locales.main_title or "Crafting", successMessage, "success")

    activeCraftSessions[src] = nil
    return true, successMessage
end)

RegisterNetEvent("forge-crafting:CancelCraft", function()
    local src = source
    local session = activeCraftSessions[src]
    if session then
        for _, ing in ipairs(session.consumed) do
            pr_lib.inventory.AddItem(src, ing.item, ing.amount)
        end
        activeCraftSessions[src] = nil
        serverNotification(src, locales.main_title or "Crafting", locales.canceled_crafting_proccess or "Fabricação cancelada! Materiais devolvidos.", "inform")
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    local session = activeCraftSessions[src]
    if session then
        for _, ing in ipairs(session.consumed) do
            pr_lib.inventory.AddItem(src, ing.item, ing.amount)
        end
        activeCraftSessions[src] = nil
    end
end)

RegisterNetEvent("forge-crafting:UpdatePosition", function(new_position, id, craft_name)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
        if row then
            local craftData = json.decode(row.crafting) or {}
            craftData.propcoords = vector3(new_position.x, new_position.y, new_position.z)
            craftData.heading = new_position.w
            pr_lib.db.execute('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', {
                json.encode(craftData),
                id
            })
            serverNotification(src, locales.main_title, locales.position_changed .. (craft_name or ""), "success")
            TriggerEvent("forge-crafting:Update")
        end
    end
end)

RegisterNetEvent("forge-crafting:UpdateHeight", function(new_height, id)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
        if row then
            local craftData = json.decode(row.crafting) or {}
            craftData.offset = tonumber(new_height)
            pr_lib.db.execute('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', {
                json.encode(craftData),
                id
            })
            TriggerEvent("forge-crafting:Update")
        end
    end
end)

RegisterNetEvent("forge-crafting:UpdateTargetable", function(state, id)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
        if row then
            local craftData = json.decode(row.crafting) or {}
            craftData.targetable = state
            pr_lib.db.execute('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', {
                json.encode(craftData),
                id
            })
            TriggerEvent("forge-crafting:Update")
        end
    end
end)

pr_lib.callback.register("forge-crafting:GetEntityModel", function(source, id)
    local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
    if row then
        local craftData = json.decode(row.crafting) or {}
        return craftData.model
    end
    return nil
end)

pr_lib.callback.register("forge-crafting:GetEntityCoords", function(source, id)
    local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
    if row then
        local craftData = json.decode(row.crafting) or {}
        return vector4(craftData.propcoords.x, craftData.propcoords.y, craftData.propcoords.z, craftData.heading or 0.0)
    end
    return nil
end)

RegisterNetEvent("forge-crafting:UpdateBlip", function(blip_data, id, craft_name)
    local src = source
    if pr_lib.framework.GetPlayer(src) then
        local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
        if row then
            local craftData = json.decode(row.crafting) or {}
            craftData.blipenable = true
            pr_lib.db.execute('UPDATE `forge-crafting` SET crafting = ?, blipdata = ? WHERE craft_id = ?', {
                json.encode(craftData),
                json.encode(blip_data),
                id
            })
            serverNotification(src, locales.main_title, locales.position_changed_blip .. (craft_name or ""), "success")
            TriggerEvent("forge-crafting:Update")
        end
    end
end)

RegisterNetEvent("forge-crafting:UpdateItems", function(id, item, need_data, task)
    local src = source
    if not pr_lib.framework.GetPlayer(src) then return end

    if task == "delete" then
        pr_lib.db.execute('DELETE FROM `forge-crafting-items` WHERE craft_id = ? AND item = ?', { id, item })
        serverNotification(src, locales.main_title, locales.success_delete_item, "success")
    elseif task == "time" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET time = ? WHERE craft_id = ? AND item = ?', { need_data, id, item })
        serverNotification(src, locales.main_title, locales.success_changed_time, "success")
    elseif task == "recipe" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET recipe = ? WHERE craft_id = ? AND item = ?', { json.encode(need_data), id, item })
        serverNotification(src, locales.main_title, locales.updated_recipe_for_item, "success")
    elseif task == "label" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET item_label = ? WHERE craft_id = ? AND item = ?', { need_data, id, item })
        serverNotification(src, locales.main_title, locales.item_label_updated, "success")
    elseif task == "amount" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET amount = ? WHERE craft_id = ? AND item = ?', { json.encode(need_data), id, item })
        serverNotification(src, locales.main_title, locales.item_amount_reward_upd, "success")
    elseif task == "model" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET model = ? WHERE craft_id = ? AND item = ?', { need_data, id, item })
        serverNotification(src, locales.main_title, locales.item_model_upd, "success")
    elseif task == "anim" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET anim = ? WHERE craft_id = ? AND item = ?', { need_data, id, item })
        serverNotification(src, locales.main_title, locales.item_anim_upd, "success")
    elseif task == "level" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET level = ? WHERE craft_id = ? AND item = ?', { need_data, id, item })
        serverNotification(src, locales.main_title, locales.item_level_upd, "success")
    end
end)

RegisterNetEvent("forge-crafting:KickPlayer", function()
    DropPlayer(source, locales.kick_reason)
end)
