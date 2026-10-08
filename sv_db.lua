-- Database initialization using pr_lib.db (universal database abstraction)

local function seedDefaultModels()
    local countResult = pr_lib.db.single("SELECT COUNT(*) as count FROM `forge-crafting-bench-models`", {})
    local count = countResult and (countResult.count or countResult['COUNT(*)']) or 0

    if tonumber(count) == 0 then
        local defaultModels = {
            {
                slug = 'default',
                label = 'Workbench (Padrão)',
                model = 'xm3_prop_xm3_bench_04b',
                center_offset = json.encode({ x = -0.05, y = 0.0, z = 0.805, w = 0.0 }),
                scale = 1.0,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = json.encode({ x = -0.85, y = 0.0, z = 0.25 }),
                cam_offset = json.encode({ x = -0.15, y = 0.0, z = 0.65 }),
            },
            {
                slug = 'workbench_2',
                label = 'Workbench 2 (Mecânica)',
                model = 'gr_prop_gr_bench_04a',
                center_offset = json.encode({ x = -0.05, y = 0.0, z = 0.805, w = 0.0 }),
                scale = 1.0,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = json.encode({ x = -0.85, y = 0.0, z = 0.25 }),
                cam_offset = json.encode({ x = -0.15, y = 0.0, z = 0.65 }),
            },
            {
                slug = 'tool_bench',
                label = 'Tool Bench (Ferramentas)',
                model = 'prop_tool_bench02_ld',
                center_offset = json.encode({ x = 0.0, y = -0.2, z = 0.92, w = -90.0 }),
                scale = 0.8,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = json.encode({ x = -0.85, y = 0.0, z = 0.25 }),
                cam_offset = json.encode({ x = -0.15, y = 0.0, z = 0.65 }),
            },
            {
                slug = 'lab_desk',
                label = 'Lab Desk (Laboratório)',
                model = 'xm_prop_lab_desk_02',
                center_offset = json.encode({ x = -0.15, y = 0.0, z = 0.9, w = 0.0 }),
                scale = 1.0,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = json.encode({ x = -0.85, y = 0.0, z = 0.25 }),
                cam_offset = json.encode({ x = -0.15, y = 0.0, z = 0.65 }),
            },
            {
                slug = 'med_bench',
                label = 'Medical Bench (Médica)',
                model = 'v_med_bench2',
                center_offset = json.encode({ x = -0.04, y = 0.0, z = 1.01, w = 0.0 }),
                scale = 1.0,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = json.encode({ x = -0.85, y = 0.0, z = 0.25 }),
                cam_offset = json.encode({ x = -0.15, y = 0.0, z = 0.65 }),
            },
            {
                slug = 'counter',
                label = 'Counter (Balcão)',
                model = 'prop_ff_counter_01',
                center_offset = json.encode({ x = -0.07, y = -0.02, z = 0.915, w = 0.0 }),
                scale = 0.9,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = json.encode({ x = -0.85, y = 0.0, z = 0.25 }),
                cam_offset = json.encode({ x = -0.15, y = 0.0, z = 0.65 }),
            },
            {
                slug = 'gr_bench_02a',
                label = 'Bancada Bunker (gr_prop_gr_bench_02a)',
                model = 'gr_prop_gr_bench_02a',
                center_offset = json.encode({ x = 0.0, y = 0.0, z = 0.85, w = 0.0 }),
                scale = 1.0,
                anim_dict = 'anim@amb@board_room@diagram_blueprints@',
                anim_name = 'idle_01_amy_skater_01',
                anim_offset = json.encode({ x = -0.85, y = 0.0, z = 0.25 }),
                cam_offset = json.encode({ x = -0.15, y = 0.0, z = 0.65 }),
            }
        }

        for _, m in ipairs(defaultModels) do
            pr_lib.db.execute([[
                INSERT IGNORE INTO `forge-crafting-bench-models`
                (`slug`, `label`, `model`, `center_offset`, `scale`, `anim_dict`, `anim_name`, `anim_offset`, `cam_offset`)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                m.slug,
                m.label,
                m.model,
                m.center_offset,
                m.scale,
                m.anim_dict,
                m.anim_name,
                m.anim_offset,
                m.cam_offset
            })
        end
    end
end

local function initDatabase()
    pr_lib.db.execute([[
        CREATE TABLE IF NOT EXISTS `forge-crafting` (
            `craft_id` int(11) NOT NULL AUTO_INCREMENT,
            `craft_name` varchar(50) DEFAULT NULL,
            `crafting` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
            `blipdata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
            `jobs` longtext DEFAULT NULL,
            `model_slug` varchar(50) DEFAULT 'default',
            PRIMARY KEY (`craft_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    pr_lib.db.execute([[
        CREATE TABLE IF NOT EXISTS `forge-crafting-bench-models` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `slug` varchar(50) NOT NULL UNIQUE,
            `label` varchar(100) NOT NULL,
            `model` varchar(100) NOT NULL,
            `center_offset` longtext NOT NULL,
            `scale` float NOT NULL DEFAULT 1.0,
            `anim_dict` varchar(100) NOT NULL DEFAULT 'anim@amb@board_room@diagram_blueprints@',
            `anim_name` varchar(100) NOT NULL DEFAULT 'idle_01_amy_skater_01',
            `anim_offset` longtext NOT NULL,
            `cam_offset` longtext NOT NULL,
            `weapon_offset` longtext DEFAULT NULL,
            PRIMARY KEY (`id`)
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
            `level` int(11) DEFAULT NULL,
            `xp` int(11) DEFAULT 10
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    pr_lib.db.execute([[
        CREATE TABLE IF NOT EXISTS `forge-crafting-player-skills` (
            `identifier` varchar(64) NOT NULL,
            `skill` varchar(50) NOT NULL DEFAULT 'crafting',
            `xp` int(11) NOT NULL DEFAULT 0,
            PRIMARY KEY (`identifier`, `skill`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    -- Migrações incrementais de colunas para tabelas legadas existentes
    local craftCols = pr_lib.db.query("SHOW COLUMNS FROM `forge-crafting`", {})
    if craftCols and type(craftCols) == "table" then
        local existingCols = {}
        for _, col in ipairs(craftCols) do
            if col.Field then
                existingCols[col.Field:lower()] = true
            end
        end

        if not existingCols['model_slug'] then
            pr_lib.db.execute("ALTER TABLE `forge-crafting` ADD `model_slug` VARCHAR(50) DEFAULT 'default';")
        end
    end

    local itemCols = pr_lib.db.query("SHOW COLUMNS FROM `forge-crafting-items`", {})
    if itemCols and type(itemCols) == "table" then
        local existingCols = {}
        for _, col in ipairs(itemCols) do
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
        if not existingCols['xp'] then
            pr_lib.db.execute("ALTER TABLE `forge-crafting-items` ADD `xp` INT(11) DEFAULT 10;")
        end
    end

    local modelCols = pr_lib.db.query("SHOW COLUMNS FROM `forge-crafting-bench-models`", {})
    if modelCols and type(modelCols) == "table" then
        local existingCols = {}
        for _, col in ipairs(modelCols) do
            if col.Field then
                existingCols[col.Field:lower()] = true
            end
        end

        if not existingCols['weapon_offset'] then
            pr_lib.db.execute("ALTER TABLE `forge-crafting-bench-models` ADD `weapon_offset` LONGTEXT DEFAULT NULL;")
        end
    end

    pr_lib.db.execute([[
        CREATE TABLE IF NOT EXISTS `forge-crafting-recipe-catalog` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `item` varchar(50) NOT NULL UNIQUE,
            `item_label` varchar(100) NOT NULL,
            `recipe` longtext NOT NULL,
            `time` int(11) NOT NULL DEFAULT 5,
            `amount` int(11) NOT NULL DEFAULT 1,
            `model` varchar(100) DEFAULT NULL,
            `anim` varchar(100) DEFAULT NULL,
            `level` int(11) DEFAULT 0,
            `xp` int(11) DEFAULT 10,
            `category` varchar(50) DEFAULT 'Geral',
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    seedDefaultModels()
    seedDefaultRecipeCatalog()
end

local function loadRecipeFile(filePath)
    local content = LoadResourceFile(GetCurrentResourceName(), filePath)
    if content then
        local fn, err = load(content)
        if fn then
            local ok, res = pcall(fn)
            if ok and type(res) == "table" and res.items then
                return res
            end
        end
    end
    return nil
end

function ImportSharedRecipesToCatalog(forceUpdate)
    local filesToLoad = {
        { path = 'shared/receita_nova.lua', category = 'Peças Novas' },
        { path = 'shared/receita_tuning.lua', category = 'Peças Tuning' }
    }

    local totalImported = 0
    for _, entry in ipairs(filesToLoad) do
        local fileData = loadRecipeFile(entry.path)
        if fileData and fileData.items then
            for _, rec in ipairs(fileData.items) do
                local recipeJson = json.encode(rec.recipe or {})
                if forceUpdate then
                    pr_lib.db.execute([[
                        INSERT INTO `forge-crafting-recipe-catalog`
                        (`item`, `item_label`, `recipe`, `time`, `amount`, `level`, `xp`, `category`)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ON DUPLICATE KEY UPDATE
                            `item_label` = VALUES(`item_label`),
                            `recipe` = VALUES(`recipe`),
                            `time` = VALUES(`time`),
                            `amount` = VALUES(`amount`),
                            `level` = VALUES(`level`),
                            `category` = VALUES(`category`)
                    ]], {
                        rec.item,
                        rec.item_label or rec.item,
                        recipeJson,
                        tonumber(rec.time) or 5,
                        tonumber(rec.amount) or 1,
                        tonumber(rec.level) or 0,
                        10,
                        entry.category
                    })
                    totalImported = totalImported + 1
                else
                    local res = pr_lib.db.execute([[
                        INSERT IGNORE INTO `forge-crafting-recipe-catalog`
                        (`item`, `item_label`, `recipe`, `time`, `amount`, `level`, `xp`, `category`)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ]], {
                        rec.item,
                        rec.item_label or rec.item,
                        recipeJson,
                        tonumber(rec.time) or 5,
                        tonumber(rec.amount) or 1,
                        tonumber(rec.level) or 0,
                        10,
                        entry.category
                    })
                    if res then
                        totalImported = totalImported + 1
                    end
                end
            end
        end
    end
    return totalImported
end

function seedDefaultRecipeCatalog()
    local countResult = pr_lib.db.single("SELECT COUNT(*) as count FROM `forge-crafting-recipe-catalog`", {})
    local count = countResult and (countResult.count or countResult['COUNT(*)']) or 0

    if tonumber(count) == 0 then
        print("[forge-crafting:db] Populando Catálogo Global de Receitas inicial a partir de receita_nova e receita_tuning...")
        local imported = ImportSharedRecipesToCatalog(false)
        print(string.format("[forge-crafting:db] Catálogo Global populado com %d receitas!", imported))
    end
end

CreateThread(function()
    initDatabase()
end)
