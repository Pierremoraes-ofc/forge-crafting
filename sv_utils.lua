local workshops = {}
local craftLobyy = {}

local function addCraftingSkill(source)
    local resource = Config.ReputationResource or 'forge-reputation'
    if GetResourceState(resource) ~= 'started' then return end

    pcall(function()
        exports[resource]:updateSkill(source, Config.CraftingSkill or 'crafting', Config.CraftingSkillReward or 5)
    end)
end

RegisterNetEvent("forge-crafting:ItemInterval", function(task, item, count)
    if IsValidTask(task) and QT.GetFromId(source) then
        if task == "add" then
            QT.AddItem(source, item, count)
            addCraftingSkill(source)
        elseif task == "remove" then
            QT.RemoveItem(source, item, count)
        end
    end
end)

QT.RegisterCallback('forge-crafting:PermisionCheck', function(source, cb)
    if IsPlayerAceAllowed(source, 'admin') or IsPlayerAceAllowed(source, 'crafting') then
        cb(true)
    else
        cb(false)
        server_notification(source, locales.main_title, locales.insufficient_permission, types.error)
    end
end)

QT.RegisterCallback('forge-crafting:fetchJobs', function(source, cb)
    local jobs = QT.GetJobs()
    local options = {}
    for k, v in pairs(jobs) do
        if v.label ~= 'Civil' then
            options[#options + 1] = { label = v.label, value = k }
        end
    end

    local gangs = QT.GetGangs()
    for k, v in pairs(gangs) do
        if v.label ~= 'Sem gangue' then
            options[#options + 1] = { label = v.label, value = k }
        end
    end
    cb(options)
end)

RegisterNetEvent('forge-crafting:CreateWorkShop', function(data)
    local craft_id = math.random(1, 1000000)
    local crafting = { model = data.prop, propcoords = vec3(data.propcoords.x, data.propcoords.y, data.propcoords.z), heading =
    data.heading, blipenable = data.blipenable, jobenable = data.jobenable }
    MySQL.Async.execute(
        'INSERT INTO `forge-crafting` (craft_id, craft_name, crafting, blipdata, jobs) VALUES (@craft_id, @craft_name, @crafting, @blipdata, @jobs)',
        {
            ['@craft_id'] = craft_id,
            ['@craft_name'] = data.craft_name,
            ['@crafting'] = json.encode(crafting),
            ['@blipdata'] = json.encode(data.blip),
            ['@jobs'] = json.encode(data.jobs),
        }, function(affectedRows)
        end)
end)

QT.RegisterCallback('forge-crafting:TableExist', function(source, cb, name)
    MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_name = @craft_name', {
        ['@craft_name'] = name
    }, function(result)
        cb(result[1] ~= nil)
    end)
end)

QT.RegisterCallback("forge-crafting:GetList", function(source, cb)
    MySQL.query('SELECT * FROM `forge-crafting`', function(result)
        if result then
            local send = {}
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                send[#send + 1] = {
                    craft_name = result[i].craft_name,
                    craft_id = result[i].craft_id,
                    jobs = json.decode(result[i].jobs),
                    crafting = craftData,
                    offset = craftData.offset and craftData.offset or 1.1,
                    targetable = craftData.targetable or false
                }
            end
            cb(send)
        else
            cb(false)
        end
    end)
end)

QT.RegisterCallback("forge-crafting:GetListItems", function(source, cb, args)
    MySQL.query('SELECT * FROM `forge-crafting-items` WHERE craft_id = ?', { args }, function(result)
        if result then
            local send = {}
            for i = 1, #result, 1 do
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
            cb(send)
        else
            cb(false)
        end
    end)
end)

QT.RegisterCallback("forge-crafting:fetchItemsFromId", function(source, cb, args)
    MySQL.query('SELECT * FROM `forge-crafting-items` WHERE craft_id = ?', { args }, function(result)
        if result then
            local send = {}
            for i = 1, #result, 1 do
                local someData = result[i]
                send[#send + 1] = {
                    craft_id = someData.craft_id,
                    item = someData.item,
                    item_label = someData.item_label,
                    recipe = json.decode(someData.recipe),
                    amount = someData.amount,
                    time = someData.time,
                    model = someData.model,
                    anim = someData.anim,
                    level = someData.level
                }
            end
            cb(send)
        else
            cb(false)
        end
    end)
end)

RegisterNetEvent("forge-crafting:ChangeName", function(id, newname)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.update('UPDATE `forge-crafting` SET craft_name = ? WHERE craft_id = ?', { newname, id })
    end
end)

RegisterNetEvent("forge-crafting:DeleteTable", function(id, name)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.Async.execute('DELETE FROM `forge-crafting` WHERE craft_id = ?', { id })
        MySQL.Async.execute('DELETE FROM `forge-crafting-items` WHERE craft_id = ?', { id })
        server_notification(source, locales.main_title, locales.sucessfullydeleted .. ' ' .. name, types.success)
    end
end)

RegisterNetEvent("forge-crafting:AddItemCrafting", function(data)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.Async.execute(
            'INSERT INTO `forge-crafting-items` (craft_id, item, item_label, recipe, time, amount, model, anim, level) VALUES (@craft_id, @item, @item_label, @recipe, @time, @amount, @model, @anim, @level)',
            {
                ['@craft_id'] = data.craft_id,
                ['@item'] = data.main_item,
                ['@item_label'] = data.item_label,
                ['@recipe'] = json.encode(data.recipe),
                ['@amount'] = data.amount,
                ['@time'] = data.time,
                ['@model'] = data.model,
                ['@anim'] = data.anim,
                ['@level'] = data.level
            }, function(result)
            end)
    end
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        MySQL.Async.fetchAll('SELECT * FROM `forge-crafting`', {}, function(result)
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                local blipData = json.decode(result[i].blipdata)
                local jobsData = json.decode(result[i].jobs)
                insert(workshops, {
                    model = craftData.model,
                    id = result[i].craft_id,
                    name = result[i].craft_name,
                    coords = vector4(craftData.propcoords.x, craftData.propcoords.y, craftData.propcoords.z,
                        craftData.heading),
                    jobenb = craftData.jobenable,
                    blipenb = craftData.blipenable,
                    blipdata = blipData,
                    jobs = jobsData,
                    offset = craftData.offset and tonumber(craftData.offset) or 1.1,
                    targetable = craftData.targetable
                })
            end
        end)
    end
end)

QT.RegisterCallback('forge-crafting:fetchTables', function(source, cb)
    cb(workshops)
end)

RegisterNetEvent("forge-crafting:Update")
AddEventHandler("forge-crafting:Update", function()
    workshops = {}
    MySQL.Async.fetchAll('SELECT * FROM `forge-crafting`', {}, function(result)
        for i = 1, #result, 1 do
            local craftData = json.decode(result[i].crafting)
            local blipData = json.decode(result[i].blipdata)
            local jobsData = json.decode(result[i].jobs)
            insert(workshops, {
                model = craftData.model,
                id = result[i].craft_id,
                name = result[i].craft_name,
                coords = vector4(craftData.propcoords.x, craftData.propcoords.y, craftData.propcoords.z,
                    craftData.heading),
                jobenb = craftData.jobenable,
                blipenb = craftData.blipenable,
                blipdata = blipData,
                jobs = jobsData,
                offset = craftData.offset and tonumber(craftData.offset) or 1.1,
                targetable = craftData.targetable
            })
        end
    end)
    Wait(50)
    TriggerClientEvent("forge-crafting:Sync", -1)
end)

RegisterNetEvent("forge-crafting:ChangeJobs", function(id, jobs)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                local ndata = { propcoords = vector3(craftData.propcoords.x, craftData.propcoords.y,
                    craftData.propcoords.z), heading = craftData.heading, jobenable = true, blipenable = craftData
                .blipenable, model = craftData.model, offset = craftData.offset }
                MySQL.update('UPDATE `forge-crafting` SET jobs = ? WHERE craft_id = ?', { json.encode(jobs), id })
                MySQL.update('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', { json.encode(ndata), id })
                server_notification(xPlayer.source, locales.main_title, locales.job_successfully_changed, types.success)
                break
            end
        end)
    end
end)

RegisterNetEvent("forge-crafting:RemoveRequirement", function(id)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.update('UPDATE `forge-crafting` SET jobs = ? WHERE craft_id = ?', { nil, id })
        MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                local ndata = { propcoords = vector3(craftData.propcoords.x, craftData.propcoords.y,
                    craftData.propcoords.z), heading = craftData.heading, jobenable = false, blipenable = craftData
                .blipenable, model = craftData.model, offset = craftData.offset }
                MySQL.update('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', { json.encode(ndata), id })
                server_notification(xPlayer.source, locales.main_title, locales.job_requirement_deleted, types.success)
                break
            end
        end)
    end
end)

QT.RegisterCallback("forge-crafting:CheckOptionsEnable", function(source, cb, id)
    MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
        for i = 1, #result, 1 do
            local craftData = json.decode(result[i].crafting)
            if craftData.jobenable then
                cb(false)
            else
                cb(true)
            end
        end
    end)
end)

QT.RegisterCallback("forge-crafting:CanCraftItem", function(source, cb, recipe)
    local totalItems = #recipe
    local itemsChecked = 0
    local canCraft = true

    for _, data in ipairs(recipe) do
        print(data.item, data.amount)
        local check = QT.HasItem(source, data.item, data.amount)
        print(check)
        if not check then
            canCraft = false
            break
        else
            itemsChecked = itemsChecked + 1
        end
    end

    if itemsChecked == totalItems then
        cb(true)
    else
        cb(false)
    end
end)

RegisterNetEvent("forge-crafting:UpdatePosition", function(new_position, id, craft_name)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                local ndata = { propcoords = vector3(new_position.x, new_position.y, new_position.z), heading =
                new_position.w, jobenable = craftData.jobenable, blipenable = craftData.blipenable, model = craftData
                .model, offset = craftData.offset }
                MySQL.update('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', { json.encode(ndata), id })
                server_notification(xPlayer.source, locales.main_title, locales.position_changed .. craft_name,
                    types.success)
                break
            end
        end)
    end
end)

RegisterNetEvent("forge-crafting:UpdateHeight", function(new_height, id)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                local ndata = { propcoords = vector3(craftData.propcoords.x, craftData.propcoords.y, craftData.propcoords.z), heading =
                craftData.heading, jobenable = craftData.jobenable, blipenable = craftData.blipenable, model = craftData
                .model, offset = tonumber(new_height) }
                MySQL.update('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', { json.encode(ndata), id })
                break
            end
        end)
    end
end)

RegisterNetEvent("forge-crafting:UpdateTargetable", function(boolean, id)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                local ndata = { propcoords = vector3(craftData.propcoords.x, craftData.propcoords.y, craftData.propcoords.z), heading =
                craftData.heading, jobenable = craftData.jobenable, blipenable = craftData.blipenable, model = craftData
                .model, offset = craftData.offset, targetable = boolean }
                MySQL.update('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', { json.encode(ndata), id })
                break
            end
        end)
    end
end)


QT.RegisterCallback("forge-crafting:GetEntityModel", function(source, cb, id)
    MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
        for i = 1, #result, 1 do
            local craftData = json.decode(result[i].crafting)
            local model = craftData.model
            cb(model)
            break
        end
    end)
end)

QT.RegisterCallback("forge-crafting:GetEntityCoords", function(source, cb, id)
    MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
        for i = 1, #result, 1 do
            local craftData = json.decode(result[i].crafting)
            local coords = vector4(craftData.propcoords.x, craftData.propcoords.y, craftData.propcoords.z,
                craftData.heading)
            cb(coords)
            break
        end
    end)
end)

RegisterNetEvent("forge-crafting:UpdateBlip", function(blip_data, id, craft_name)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        MySQL.Async.fetchAll('SELECT * FROM `forge-crafting` WHERE craft_id = ?', { id }, function(result)
            for i = 1, #result, 1 do
                local craftData = json.decode(result[i].crafting)
                local ndata = { propcoords = vector3(craftData.propcoords.x, craftData.propcoords.y,
                    craftData.propcoords.z), heading = craftData.heading, jobenable = craftData.jobenable, blipenable = true, model =
                craftData.model, offset = craftData.offset }
                MySQL.update('UPDATE `forge-crafting` SET crafting = ? WHERE craft_id = ?', { json.encode(ndata), id })
                MySQL.update('UPDATE `forge-crafting` SET blipdata = ? WHERE craft_id = ?', { json.encode(blip_data), id })
                server_notification(xPlayer.source, locales.main_title, locales.position_changed_blip .. craft_name,
                    types.success)
                break
            end
        end)
    end
end)

RegisterNetEvent("forge-crafting:UpdateItems", function(id, item, need_data, task)
    local xPlayer = QT.GetFromId(source)
    if xPlayer then
        if task == "delete" then
            MySQL.Async.execute('DELETE FROM `forge-crafting-items` WHERE craft_id = ? AND item = ?', { id, item })
            server_notification(xPlayer.source, locales.main_title, locales.success_delete_item, types.success)
        elseif task == "time" then
            MySQL.update('UPDATE `forge-crafting-items` SET time = ? WHERE craft_id = ? AND item = ?', { need_data, id, item })
            server_notification(xPlayer.source, locales.main_title, locales.success_changed_time, types.success)
        elseif task == "recipe" then
            MySQL.update('UPDATE `forge-crafting-items` SET recipe = ? WHERE craft_id = ? AND item = ? ',
                { json.encode(need_data), id, item })
            server_notification(xPlayer.source, locales.main_title, locales.updated_recipe_for_item, types.success)
        elseif task == "label" then
            MySQL.update('UPDATE `forge-crafting-items` SET item_label = ? WHERE craft_id = ? AND item = ? ',
                { need_data, id, item })
            server_notification(xPlayer.source, locales.main_title, locales.item_label_updated, types.success)
        elseif task == "amount" then
            MySQL.update('UPDATE `forge-crafting-items` SET amount = ? WHERE craft_id = ? AND item = ? ',
                { json.encode(need_data), id, item })
            server_notification(xPlayer.source, locales.main_title, locales.item_amount_reward_upd, types.success)
        elseif task == "model" then
            MySQL.update('UPDATE `forge-crafting-items` SET model = ? WHERE craft_id = ? AND item = ? ',
                { need_data, id, item })
            server_notification(xPlayer.source, locales.main_title, locales.item_model_upd, types.success)
        elseif task == "anim" then
            MySQL.update('UPDATE `forge-crafting-items` SET anim = ? WHERE craft_id = ? AND item = ? ',
                { need_data, id, item })
            server_notification(xPlayer.source, locales.main_title, locales.item_anim_upd, types.success)
        elseif task == "level" then
            MySQL.update('UPDATE `forge-crafting-items` SET level = ? WHERE craft_id = ? AND item = ? ',
                { need_data, id, item })
            server_notification(xPlayer.source, locales.main_title, locales.item_level_upd, types.success)
        end
    end
end)

RegisterNetEvent("forge-crafting:KickPlayer", function()
    DropPlayer(source, locales.kick_reason)
end)
