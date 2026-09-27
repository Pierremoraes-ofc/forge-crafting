types  = { -- # in this part change into your types from notification 
    info = "info",
    success = "success",
    error = "error",
 }
 
 function notification(title, message, type) -- # and in this part you can change notification export
    lib.notify({
                type = type, 
                title = title, 
                description = message,
                position = "center-left",
                duration = 10000
            })
 end
 

insert = function(t, v) -- # instead of table.insert micro optimisation 
    t[#t + 1] = v
end

function progress(message, duration, type)
    if Config.OxProgress then   
        if type == 'circle' then
          return lib.progressCircle({
                duration = duration * 1000,
                label = message,
                position = 'bottom',
                useWhileDead = false,
                canCancel = true, -- # if you dont want that player can cancel progress then change to false 
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                    mouse = false
                },
            })
        elseif type == 'default' then
         return lib.progressBar({
                duration = duration * 1000,
                label = message,
                useWhileDead = false,
                canCancel = true, -- # if you dont want that player can cancel progress then change to false 
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                    mouse = false
                },
            })
        end
    end
    -- # if you are using other progress there is a example AND CHANGE Config.OxProgress to false into config file;
    -- #  exports['progressBars']:startUI(duration * 1000, message);
end

QT = {
    TriggerCallback = function(name, cb, ...)
        if ESX ~= nil then
            ESX.TriggerServerCallback(name, cb, ...)
        elseif QBCore ~= nil then
            QBCore.Functions.TriggerCallback(name, cb, ...)
        end
    end,

    getjob = function()
        if ESX ~= nil then
            return ESX.GetPlayerData().job.name
        elseif QBCore ~= nil then
            return QBCore.Functions.GetPlayerData().job.name
        end
    end,

    getgang = function()
        if ESX ~= nil then
            return ESX.GetPlayerData().gang.name
        elseif QBCore ~= nil then
            return QBCore.Functions.GetPlayerData().gang.name
        end
    end
    
}

function animation(animDict) -- do not delete this or change nothing
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(100)
        end
    end
    return animDict
end