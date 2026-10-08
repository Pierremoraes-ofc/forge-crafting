function server_notification(player, title, message, type)
    -- TriggerClientEvent('okokNotify:Alert', player, title, message, 5000, type)
end

types  = { -- # in this part change into your types from notification 
    info = "info",
    success = "success",
    error = "error",
 }

insert = function(t, v)
    t[#t + 1] = v
end

function IsValidTask(task)
    if task == "add" or task == "remove" then
        return true
    else
        return false
    end
end

QT = {

    RegisterCallback = function(name, cb)
        if ESX ~= nil then 
            ESX.RegisterServerCallback(name, cb)
        elseif QBCore ~= nil then
            QBCore.Functions.CreateCallback(name, cb)
        end
    end,
    
    GetFromId = function(src)
        if ESX ~= nil then
            return ESX.GetPlayerFromId(src)
        elseif QBCore ~= nil then
            return QBCore.Functions.GetPlayer(src)
        end
    end,

    GetJobs = function()
        if ESX ~= nil then
            return ESX.GetJobs()
        elseif QBCore ~= nil then
            return exports.qbx_core:GetJobs()
        end
    end,

    GetGangs = function()
        if ESX ~= nil then
            return ESX.GetGangs()
        elseif QBCore ~= nil then
            return exports.qbx_core:GetGangs()
        end
    end,

  GetGroup = function(src)
        local xPlayer = QT.GetFromId(src)
        if xPlayer then
            if ESX ~= nil then
                return xPlayer.getGroup()
            elseif QBCore ~= nil then
                local permissions = QBCore.Functions.GetPermission(src)
                for group, hasPermission in pairs(permissions) do
                    if hasPermission then
                        return group
                    end
                end
            end
        end
        return nil
    end,

    GetInventory = function(src)
        local xPlayer = QT.GetFromId(tonumber(src))
        local items, inv = {}, {}
    
        if ESX ~= nil then
            items = xPlayer.getInventory()
        elseif QBCore ~= nil then
            items = xPlayer.PlayerData.items
        end
    
        for k,v in pairs(items) do
            if (v.amount and v.amount > 0) or (v.count and v.count > 0) then
                table.insert(inv, {
                    name  = v.name, 
                    label = v.label,
                    count = (v.amount or v.count),
                    info  = (v.info or v.metadata or false),
                })
            end
        end
    
        return inv
    end,

    AddItem = function(src, item, amount)
        local src = QT.GetSource(src)
        local xPlayer = QT.GetFromId(src)
        if ESX ~= nil then
            xPlayer.addInventoryItem(item, amount)
        elseif QBCore ~= nil then
            xPlayer.Functions.AddItem(item, amount)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[tostring(item)], "add")
        end
    end,


    RemoveItem = function(src, item, amount)
        local src = QT.GetSource(src)
        local xPlayer = QT.GetFromId(src)
        if ESX ~= nil then
            xPlayer.removeInventoryItem(item, amount)
        elseif QBCore ~= nil then
            xPlayer.Functions.RemoveItem(item, amount)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[tostring(item)], "remove")
        end
    end,

    HasItem = function(src, item, amount)
        local xPlayer = QT.GetFromId(tonumber(src))
        local inv = exports.ox_inventory:GetItemCount(src, item)
        if inv >= amount then
            return true, inv
        end
        -- for k,v in pairs(inv) do
        --     if v.name == item then
        --         if v.count >= amount then
        --             return true, v.count
        --         else
        --             return false, v.count
        --         end
        --     end
        -- end
        return false, 0
    end,

    GetItem = function(src, item)
        local xPlayer = QT.GetFromId(tonumber(src))
        if ESX ~= nil then
            local invItem = xPlayer.getInventoryItem(item)
            if invItem == nil then
                return nil
            else
                return {name = invItem.name, label = invItem.label, count = invItem.count}
            end
        elseif QBCore ~= nil then
                local invItem = xPlayer.Functions.GetItemByName(item)
                if invItem ~= nil then
                    return {name = invItem.name, label = invItem.label, count = invItem.amount}
                else
                    return nil
                end
        end
    end,

    GetFromIdentifier = function(identifier)
        if ESX ~= nil then
            return ESX.GetPlayerFromIdentifier(identifier)
        elseif QBCore ~= nil then
            return QBCore.Functions.GetPlayerByCitizenId(identifier)
        end
    end,

    GetSource = function(src)
        local xPlayer = QT.GetFromId(tonumber(src))
        while xPlayer == nil do
            Wait(500)
            xPlayer = QT.GetFromId(tonumber(src))
        end
        if ESX ~= nil then
            return xPlayer.source
        elseif QBCore ~= nil then
            return xPlayer.PlayerData.source
        end
    end,

    GetSrcFromIdentifier = function(identifier)
        local xPlayer = QT.GetFromIdentifier(identifier)
        if ESX ~= nil then
            return xPlayer ~= nil and xPlayer.source or nil
        elseif QBCore ~= nil then
            return xPlayer ~= nil and xPlayer.PlayerData.source or nil
        end
    end,

    GetIdentifier = function(src)
        local xPlayer = QT.GetFromId(tonumber(src))
        if ESX ~= nil then
            return xPlayer.identifier
        elseif QBCore ~= nil then
            return xPlayer.PlayerData.citizenid
        end
    end,
    
    GetName = function(src)
        local xPlayer = QT.Player.GetFromId(tonumber(src))
        if ESX ~= nil then
            return xPlayer.getName()
        elseif QBCore ~= nil then
            return xPlayer.PlayerData.name
        end
    end,
    
}

