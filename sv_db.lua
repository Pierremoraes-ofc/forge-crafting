-- Database initialization using pr_lib.db (universal database abstraction)

local function initDatabase()
    pr_lib.db.execute([[
        CREATE TABLE IF NOT EXISTS `forge-crafting` (
            `craft_id` int(11) NOT NULL AUTO_INCREMENT,
            `craft_name` varchar(50) DEFAULT NULL,
            `crafting` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
            `blipdata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
            `jobs` longtext DEFAULT NULL,
            PRIMARY KEY (`craft_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    pr_lib.db.execute([[
        CREATE TABLE IF NOT EXISTS `forge-crafting-items` (
            `craft_id` int(11) DEFAULT NULL,
            `item` varchar(50) DEFAULT NULL,
            `item_label` varchar(50) DEFAULT NULL,
            `recipe` longtext DEFAULT NULL,
            `time` int(11) DEFAULT NULL,
            `amount` int(11) DEFAULT NULL,
            `model` longtext DEFAULT NULL,
            `anim` longtext DEFAULT NULL,
            `level` int(11) DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    -- Verificações e migrações incrementais de colunas para tabelas legadas existentes
    local cols = pr_lib.db.query("SHOW COLUMNS FROM `forge-crafting-items`", {})
    if cols and type(cols) == "table" then
        local existingCols = {}
        for _, col in ipairs(cols) do
            if col.Field then
                existingCols[col.Field:lower()] = true
            end
        end

        if not existingCols['model'] then
            pr_lib.db.execute("ALTER TABLE `forge-crafting-items` ADD `model` LONGTEXT DEFAULT NULL;")
        end
        if not existingCols['anim'] then
            pr_lib.db.execute("ALTER TABLE `forge-crafting-items` ADD `anim` LONGTEXT DEFAULT NULL;")
        end
        if not existingCols['level'] then
            pr_lib.db.execute("ALTER TABLE `forge-crafting-items` ADD `level` INT(11) DEFAULT NULL;")
        end
    end
end

CreateThread(function()
    initDatabase()
end)
