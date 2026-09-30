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

local function isValidTask(task)
    return task == "add" or task == "remove"
end

RegisterNetEvent("forge-crafting:ItemInterval", function(task, item, count)
    local src = source
    if isValidTask(task) and pr_lib.framework.GetPlayer(src) then
        if task == "add" then
            pr_lib.inventory.AddItem(src, item, count)
            addCraftingSkill(src)
        elseif task == "remove" then
            pr_lib.inventory.RemoveItem(src, item, count)
        end
    end
end)

pr_lib.callback.register('forge-crafting:PermisionCheck', function(source)
    if IsPlayerAceAllowed(source, 'admin') or IsPlayerAceAllowed(source, 'crafting') then
        return true
    else
        local permMsg = locales.insufficient_permission or locales.insuficient_permission or "Sem permissão"
        serverNotification(source, locales.main_title, permMsg, "error")
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
