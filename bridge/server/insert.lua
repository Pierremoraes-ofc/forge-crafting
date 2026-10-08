AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        MySQL.Sync.execute([[
            CREATE TABLE IF NOT EXISTS `forge-crafting` (
                `craft_id` int(11) NOT NULL AUTO_INCREMENT,
                `craft_name` varchar(50) DEFAULT NULL,
                `crafting` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`crafting`)),
                `blipdata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`blipdata`)),
                `jobs` longtext DEFAULT NULL,
                PRIMARY KEY (`craft_id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        ]])
        MySQL.Sync.execute([[
            CREATE TABLE IF NOT EXISTS `forge-crafting-items` (
                `craft_id` int(11) DEFAULT NULL,
                `item` varchar(50) DEFAULT NULL,
                `item_label` varchar(50) DEFAULT NULL,
                `recipe` longtext DEFAULT NULL,
                `time` int(11) DEFAULT NULL,
                `amount` int(11) DEFAULT NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
        ]])

        -- Verifica se a coluna 'model' existe antes de tentar adicioná-la
        local result = MySQL.Sync.fetchAll("SHOW COLUMNS FROM `forge-crafting-items` LIKE 'model';")
        if #result == 0 then
            MySQL.Sync.execute([[
                ALTER TABLE `forge-crafting-items`
                ADD `model` LONGTEXT DEFAULT NULL;
            ]])
        end

        -- Verifica se a coluna 'anim' existe antes de tentar adicioná-la
        local result = MySQL.Sync.fetchAll("SHOW COLUMNS FROM `forge-crafting-items` LIKE 'anim';")
        if #result == 0 then
            MySQL.Sync.execute([[
                ALTER TABLE `forge-crafting-items`
                ADD `anim` LONGTEXT DEFAULT NULL;
            ]])
        end

        -- Verifica se a coluna 'anim' existe antes de tentar adicioná-la
        local result = MySQL.Sync.fetchAll("SHOW COLUMNS FROM `forge-crafting-items` LIKE 'level';")
        if #result == 0 then
            MySQL.Sync.execute([[
                ALTER TABLE `forge-crafting-items`
                ADD `level` int(11) DEFAULT NULL;
            ]])
        end
    end
end)
