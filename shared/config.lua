Config = {}
Config.Framework = "qb" -- # esx, qb
Config.Target = "ox_target" -- # ox_target, qb-target 
Config.OxProgress = true -- # if you 're using ox progress just change to true but if you 're using other progress you must to go into bridge/client/editable.lua
Config.ImagePath = GetConvar('inventory:imagepath', 'nui://ox_inventory/web/images'):gsub('^nui://', ''):gsub('/+$', '') .. '/' -- # where images for items will display
Config.ReputationResource = 'forge-reputation'
Config.CraftingSkill = 'crafting'
Config.CraftingSkillReward = 5

-- # inventory paths 

--[[
    "qb-inventory/html/images/"
    "lj-inventory/html/images/"
    "ox_inventory/web/images/"
    "qs-inventory/html/images/"
    "ps-inventory/html/images/"
]]

Config.Authorization = { -- JUST FOR ESX  FOR QB READ UNDER!
    ['admin'] = true,
    ['god'] = true,
}

--  QB add in cfg add_ace group.admin crafting allow 

Config.Pfx = "craft:"
Config.CreateTableCommand = 'create'
Config.EditMenuCommand = 'edit'
Config.Debug = false -- # for debuging box zones
