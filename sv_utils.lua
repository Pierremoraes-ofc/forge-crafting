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

local function getSourceIdentifier(source)
    if not source then return nil end
    if pr_lib and pr_lib.framework and pr_lib.framework.GetPlayerIdentifier then
        local id = pr_lib.framework.GetPlayerIdentifier(source)
        if id and id ~= "" then return id end
    end
    if pr_lib and pr_lib.framework and pr_lib.framework.GetPlayer then
        local xPlayer = pr_lib.framework.GetPlayer(source)
        if xPlayer then
            if xPlayer.identifier then return xPlayer.identifier end
            if xPlayer.PlayerData and xPlayer.PlayerData.citizenid then return xPlayer.PlayerData.citizenid end
            if xPlayer.citizenid then return xPlayer.citizenid end
        end
    end
    local license = GetPlayerIdentifierByType and GetPlayerIdentifierByType(source, 'license')
    if license then return license end
    local ids = GetPlayerIdentifiers(source)
    return (ids and ids[1]) or tostring(source)
end

local function getInternalPlayerXP(source, skillName)
    skillName = skillName or 'crafting'
    local id = getSourceIdentifier(source)
    if not id then return 0 end
    local row = pr_lib.db.single('SELECT xp FROM `forge-crafting-player-skills` WHERE identifier = ? AND skill = ?', { id, skillName })
    return (row and tonumber(row.xp)) or 0
end

local function addInternalPlayerXP(source, xpAmount, skillName)
    xpAmount = tonumber(xpAmount) or 0
    if xpAmount <= 0 then return end
    skillName = skillName or 'crafting'
    local id = getSourceIdentifier(source)
    if not id then return end
    pr_lib.db.execute([[
        INSERT INTO `forge-crafting-player-skills` (identifier, skill, xp)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE xp = xp + ?
    ]], { id, skillName, xpAmount, xpAmount })
end

local function getPlayerSkillData(source)
    local skillName = (Config.SkillsSystem and Config.SkillsSystem.skillName) or Config.CraftingSkill or 'crafting'

    -- 1. Consultar export configurado pelo usuário em Config.SkillsSystem.getCurrentSkill
    if Config.SkillsSystem and Config.SkillsSystem.enabled and type(Config.SkillsSystem.getCurrentSkill) == 'function' then
        local ok, data = pcall(Config.SkillsSystem.getCurrentSkill, source, skillName)
        if ok and data ~= nil then
            if type(data) == 'table' then
                local lvl = tonumber(data.level or data.currentLevel or data.lvl)
                local xp = tonumber(data.xp or data.currentXP or data.experience)
                if not lvl and xp then
                    lvl = Config.GetLevelFromXP and Config.GetLevelFromXP(xp) or 1
                end
                if not xp and lvl then
                    xp = Config.GetXPForLevel and Config.GetXPForLevel(lvl) or 0
                end
                return (lvl or 1), (xp or 0)
            elseif type(data) == 'number' then
                -- Se o valor for muito alto (> 100) e não for um nível explícito no Config.Levels, interpreta como XP
                if data > 100 and not (Config.Levels and Config.Levels[data]) then
                    local calculatedLvl = Config.GetLevelFromXP and Config.GetLevelFromXP(data) or 1
                    return calculatedLvl, data
                else
                    local requiredXp = Config.GetXPForLevel and Config.GetXPForLevel(data) or 0
                    return data, requiredXp
                end
            elseif type(data) == 'string' then
                if data:lower() == 'maestria' then
                    return 999999, 999999
                end
                local num = tonumber(data)
                if num then
                    local reqXp = Config.GetXPForLevel and Config.GetXPForLevel(num) or 0
                    return num, reqXp
                end
            end
        end
    end

    -- 2. Fallback: forge-reputation
    local resource = Config.ReputationResource or 'forge-reputation'
    if GetResourceState(resource) == 'started' then
        local ok, level = pcall(function()
            return exports[resource]:getCurrentLevel(source, skillName)
        end)
        if ok and level ~= nil then
            if type(level) == 'string' and level:lower() == 'maestria' then
                return 999999, 999999
            end
            local lvlNum = tonumber(level) or 1
            local reqXp = Config.GetXPForLevel and Config.GetXPForLevel(lvlNum) or 0
            return lvlNum, reqXp
        end
    end

    -- 3. Fallback: Banco de dados interno do forge-crafting
    local internalXP = getInternalPlayerXP(source, skillName)
    local level = Config.GetLevelFromXP and Config.GetLevelFromXP(internalXP) or 1
    return level, internalXP
end

local function getPlayerLevel(source)
    local level, _ = getPlayerSkillData(source)
    return level or 1
end

local function getPlayerXP(source)
    local _, xp = getPlayerSkillData(source)
    return xp or 0
end

local function addCraftingSkill(source, xpAmount, item, amount)
    xpAmount = tonumber(xpAmount) or Config.CraftingSkillReward or 10
    local skillName = (Config.SkillsSystem and Config.SkillsSystem.skillName) or Config.CraftingSkill or 'crafting'

    -- 1. Obter estado atual antes da premiação
    local currentLevel, currentXP = getPlayerSkillData(source)
    local newXP = (currentXP or 0) + xpAmount
    local newLevel = Config.GetLevelFromXP and Config.GetLevelFromXP(newXP) or (currentLevel or 1)

    -- Salva no banco de dados interno como persistência garantida
    addInternalPlayerXP(source, xpAmount, skillName)

    -- 2. Enviar para o export do script de skills configurado pelo usuário
    if Config.SkillsSystem and Config.SkillsSystem.enabled and type(Config.SkillsSystem.addSkillXP) == 'function' then
        pcall(Config.SkillsSystem.addSkillXP, source, xpAmount, newLevel, newXP, skillName)
    else
        local resource = Config.ReputationResource or 'forge-reputation'
        if GetResourceState(resource) == 'started' then
            pcall(function()
                exports[resource]:updateSkill(source, skillName, xpAmount)
            end)
        end
    end

    -- 3. Notificação parabenizando o jogador se ele subiu de nível!
    if newLevel > currentLevel then
        serverNotification(source, locales.main_title, string.format("Parabéns! Você alcançou o Nível %d de Crafting!", newLevel), "success")
    end

    -- 4. Disparar eventos de sincronização
    TriggerEvent('forge-crafting:onCraftFinished', source, item, amount, xpAmount, newLevel)
    TriggerClientEvent('forge-crafting:onCraftFinished', source, item, amount, xpAmount, newLevel)
    TriggerClientEvent('forge-crafting:updatePlayerLevel', source, newLevel, newXP)
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

local function isPlayerAuthorizedForBench(source, bench)
    if not bench.jobenb or not bench.jobs then
        return true, nil
    end

    local jobsData = bench.jobs
    if type(jobsData) ~= "table" then
        return true, nil
    end

    local playerJob = pr_lib.framework and pr_lib.framework.GetPlayerJob and pr_lib.framework.GetPlayerJob(source)
    local playerGang = pr_lib.framework and pr_lib.framework.GetPlayerGang and pr_lib.framework.GetPlayerGang(source)

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
                if not onDuty and pr_lib.framework and pr_lib.framework.GetPlayer then
                    local xPlayer = pr_lib.framework.GetPlayer(source)
                    if xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.job then
                        onDuty = xPlayer.PlayerData.job.onduty or xPlayer.PlayerData.job.onDuty or false
                    end
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
registerServerAdminCommand("benchmodels", "forge-crafting:BenchModelsMenu")
registerServerAdminCommand("receitas", "forge-crafting:RecipeCatalogMenu")
registerServerAdminCommand("recipecatalog", "forge-crafting:RecipeCatalogMenu")

if Config.Pfx and Config.Pfx ~= "" then
    registerServerAdminCommand(Config.Pfx .. Config.CreateTableCommand, "forge-crafting:CreateMenu")
    registerServerAdminCommand(Config.Pfx .. Config.EditMenuCommand, "forge-crafting:EditMenu")
    registerServerAdminCommand(Config.Pfx .. "benchmodels", "forge-crafting:BenchModelsMenu")
    registerServerAdminCommand(Config.Pfx .. "receitas", "forge-crafting:RecipeCatalogMenu")
    registerServerAdminCommand(Config.Pfx .. "recipecatalog", "forge-crafting:RecipeCatalogMenu")
end

pr_lib.callback.register('forge-crafting:PermisionCheck', function(source)
    if isPlayerAdmin(source) then
        return true
    else
        serverNotification(source, locales.main_title, locales.insufficient_permission, "error")
        return false
    end
end)

-- =====================================================
--  Configuração Persistente da Tela de Repouso e Tema Visual (JSON)
-- =====================================================
local STANDBY_CONFIG_FILE = "data/standby_config.json"

local DEFAULT_THEME = {
    logo = "https://i.ibb.co/sphpgQs6/forge-flame.png",
    title = "FORGE CRAFTING",
    subtitle = "BANCADA DE TRABALHO",

    standby_bg = "radial-gradient(circle at center, rgba(17, 24, 39, 0.96) 0%, rgba(10, 14, 23, 0.98) 100%)",
    standby_bg_image = "",
    standby_glow_color = "rgba(56, 189, 248, 0.15)",
    standby_border_color = "rgba(56, 189, 248, 0.25)",
    standby_title_color = "#f8fafc",
    standby_subtitle_color = "#38bdf8",

    bench_bg = "rgba(15, 20, 29, 0.95)",
    bench_bg_image = "",
    bench_border_color = "rgba(255, 255, 255, 0.12)",
    bench_neon_color = "#38bdf8",

    header_title_color = "#f8fafc",
    header_subtitle_color = "#94a3b8",
    level_badge_bg = "rgba(30, 41, 59, 0.7)",
    level_badge_color = "#38bdf8",

    search_bg = "rgba(15, 23, 42, 0.6)",
    search_border = "rgba(255, 255, 255, 0.08)",
    search_text_color = "#f1f5f9",

    recipe_card_bg = "rgba(255, 255, 255, 0.02)",
    recipe_card_border = "rgba(255, 255, 255, 0.05)",
    recipe_card_active_bg = "linear-gradient(90deg, rgba(59, 130, 246, 0.18) 0%, rgba(59, 130, 246, 0.04) 100%)",
    recipe_card_active_border = "#3b82f6",
    recipe_card_active_glow = "rgba(59, 130, 246, 0.25)",

    craft_btn_bg = "linear-gradient(135deg, #3b82f6 0%, #2563eb 100%)",
    craft_btn_hover = "linear-gradient(135deg, #60a5fa 0%, #3b82f6 100%)",
    craft_btn_glow = "rgba(37, 99, 235, 0.35)",
    craft_btn_text = "#ffffff",

    mat_card_bg = "rgba(255, 255, 255, 0.02)",
    mat_card_sufficient_border = "rgba(34, 197, 94, 0.25)",
    mat_card_sufficient_color = "#4ade80",
    mat_card_insufficient_border = "rgba(239, 68, 68, 0.25)",
    mat_card_insufficient_color = "#f87171",

    detail_card_bg = "linear-gradient(135deg, rgba(30, 41, 59, 0.4) 0%, rgba(15, 23, 42, 0.4) 100%)",
    detail_card_border = "rgba(255, 255, 255, 0.08)",
    detail_badge_bg = "rgba(255, 255, 255, 0.04)",
    detail_badge_color = "#94a3b8",
    detail_xp_color = "#38bdf8"
}

local CurrentThemeConfig = json.decode(json.encode(DEFAULT_THEME))

local function loadStandbyConfig()
    local content = LoadResourceFile(GetCurrentResourceName(), STANDBY_CONFIG_FILE)
    if content and content ~= "" then
        local ok, data = pcall(json.decode, content)
        if ok and type(data) == "table" then
            for k, v in pairs(DEFAULT_THEME) do
                if data[k] == nil then
                    data[k] = v
                end
            end
            CurrentThemeConfig = data
            Config.StandbyLogo = data.logo
            Config.StandbyTitle = data.title
            Config.StandbySubtitle = data.subtitle
            return CurrentThemeConfig
        end
    end

    CurrentThemeConfig = json.decode(json.encode(DEFAULT_THEME))
    SaveResourceFile(GetCurrentResourceName(), STANDBY_CONFIG_FILE, json.encode(CurrentThemeConfig, { indent = true }), -1)
    return CurrentThemeConfig
end

CreateThread(function()
    Wait(100)
    loadStandbyConfig()
end)

pr_lib.callback.register('forge-crafting:getStandbyConfig', function(source)
    if not CurrentThemeConfig or not next(CurrentThemeConfig) then
        loadStandbyConfig()
    end
    return CurrentThemeConfig
end)

RegisterNetEvent('forge-crafting:UpdateStandbyConfig', function(newConfig)
    local src = source
    if not isPlayerAdmin(src) then
        serverNotification(src, locales.main_title, locales.insufficient_permission or "Sem permissão.", "error")
        return
    end

    if type(newConfig) ~= "table" then return end

    for k, v in pairs(newConfig) do
        CurrentThemeConfig[k] = v
    end

    Config.StandbyLogo = CurrentThemeConfig.logo or Config.StandbyLogo
    Config.StandbyTitle = CurrentThemeConfig.title or Config.StandbyTitle
    Config.StandbySubtitle = CurrentThemeConfig.subtitle or Config.StandbySubtitle

    local saved = SaveResourceFile(GetCurrentResourceName(), STANDBY_CONFIG_FILE, json.encode(CurrentThemeConfig, { indent = true }), -1)
    if saved then
        serverNotification(src, locales.main_title, "Configurações visuais salvas com sucesso!", "success")
        TriggerClientEvent('forge-crafting:SyncStandbyConfig', -1, CurrentThemeConfig)
    else
        serverNotification(src, locales.main_title, "Erro ao salvar arquivo JSON de configuração.", "error")
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

pr_lib.callback.register('forge-crafting:fetchFrameworkAuthList', function(source)
    local jobList = {}
    local gangList = {}

    local rawJobs = pr_lib.framework and pr_lib.framework.GetFrameworkJobs and pr_lib.framework.GetFrameworkJobs() or {}
    for k, v in pairs(rawJobs) do
        local label = type(v) == "table" and (v.label or k) or tostring(v)
        if label ~= 'Civil' and label ~= 'unemployed' and k ~= 'unemployed' then
            jobList[#jobList + 1] = {
                label = string.format("%s (%s)", label, k),
                value = k,
                name = k,
                default_label = label
            }
        end
    end

    table.sort(jobList, function(a, b)
        return (a.label or a.name or ''):lower() < (b.label or b.name or ''):lower()
    end)

    local rawGangs = pr_lib.framework and pr_lib.framework.GetFrameworkGangs and pr_lib.framework.GetFrameworkGangs() or {}
    for k, v in pairs(rawGangs) do
        local label = type(v) == "table" and (v.label or k) or tostring(v)
        if label ~= 'Sem gangue' and label ~= 'none' and k ~= 'none' then
            gangList[#gangList + 1] = {
                label = string.format("%s (%s)", label, k),
                value = k,
                name = k,
                default_label = label
            }
        end
    end

    table.sort(gangList, function(a, b)
        return (a.label or a.name or ''):lower() < (b.label or b.name or ''):lower()
    end)

    return {
        jobs = jobList,
        gangs = gangList
    }
end)

RegisterNetEvent('forge-crafting:CreateWorkShop', function(data)
    local modelSlug = data.model_slug or 'default'
    local crafting = {
        model = data.prop,
        model_slug = modelSlug,
        propcoords = vec3(data.propcoords.x, data.propcoords.y, data.propcoords.z),
        heading = data.heading,
        blipenable = data.blipenable,
        jobenable = data.jobenable
    }

    pr_lib.db.insert(
        'INSERT INTO `forge-crafting` (craft_name, crafting, blipdata, jobs, model_slug) VALUES (?, ?, ?, ?, ?)',
        {
            data.craft_name,
            json.encode(crafting),
            json.encode(data.blip),
            json.encode(data.jobs),
            modelSlug
        }
    )

    TriggerEvent("forge-crafting:Update")
end)

local function safeJsonDecode(val, fallback)
    if val == nil then return fallback end
    if type(val) == "table" then return val end
    if type(val) == "string" and val ~= "" and val ~= "null" then
        local ok, res = pcall(json.decode, val)
        if ok and type(res) == "table" then return res end
    end
    return fallback
end

pr_lib.callback.register('forge-crafting:getBenchModels', function(source)
    local rows = pr_lib.db.query('SELECT * FROM `forge-crafting-bench-models` ORDER BY id ASC', {})
    if not rows then return {} end

    local models = {}
    for i = 1, #rows do
        local r = rows[i]
        models[#models + 1] = {
            id = r.id,
            slug = r.slug,
            label = r.label,
            model = r.model,
            center_offset = safeJsonDecode(r.center_offset, { x = 0.0, y = 0.0, z = 0.8, w = 0.0 }),
            scale = tonumber(r.scale) or 1.0,
            anim_dict = r.anim_dict,
            anim_name = r.anim_name,
            anim_offset = safeJsonDecode(r.anim_offset, { x = -0.85, y = 0.0, z = 0.25 }),
            cam_offset = safeJsonDecode(r.cam_offset, { x = -0.15, y = 0.0, z = 0.65 }),
            weapon_offset = safeJsonDecode(r.weapon_offset, nil)
        }
    end
    return models
end)

pr_lib.callback.register('forge-crafting:saveBenchModel', function(source, modelData)
    if not isPlayerAdmin(source) then return false, "Sem permissão." end
    if not modelData or not modelData.slug or not modelData.model then return false, "Dados inválidos." end

    local centerJson = type(modelData.center_offset) == "table" and json.encode(modelData.center_offset) or modelData.center_offset
    local animJson = type(modelData.anim_offset) == "table" and json.encode(modelData.anim_offset) or modelData.anim_offset
    local camJson = type(modelData.cam_offset) == "table" and json.encode(modelData.cam_offset) or modelData.cam_offset
    local weaponJson = type(modelData.weapon_offset) == "table" and json.encode(modelData.weapon_offset) or modelData.weapon_offset

    local existing = pr_lib.db.single('SELECT id FROM `forge-crafting-bench-models` WHERE slug = ?', { modelData.slug })
    if existing then
        pr_lib.db.execute([[
            UPDATE `forge-crafting-bench-models`
            SET label = ?, model = ?, center_offset = ?, scale = ?, anim_dict = ?, anim_name = ?, anim_offset = ?, cam_offset = ?, weapon_offset = ?
            WHERE slug = ?
        ]], {
            modelData.label or modelData.slug,
            modelData.model,
            centerJson,
            tonumber(modelData.scale) or 1.0,
            modelData.anim_dict or 'anim@amb@board_room@diagram_blueprints@',
            modelData.anim_name or 'idle_01_amy_skater_01',
            animJson,
            camJson,
            weaponJson,
            modelData.slug
        })
    else
        pr_lib.db.insert([[
            INSERT INTO `forge-crafting-bench-models`
            (slug, label, model, center_offset, scale, anim_dict, anim_name, anim_offset, cam_offset, weapon_offset)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            modelData.slug,
            modelData.label or modelData.slug,
            modelData.model,
            centerJson,
            tonumber(modelData.scale) or 1.0,
            modelData.anim_dict or 'anim@amb@board_room@diagram_blueprints@',
            modelData.anim_name or 'idle_01_amy_skater_01',
            animJson,
            camJson,
            weaponJson
        })
    end

    TriggerEvent("forge-crafting:Update")
    return true
end)

pr_lib.callback.register('forge-crafting:deleteBenchModel', function(source, slug)
    if not isPlayerAdmin(source) then return false, "Sem permissão." end
    if slug == 'default' then return false, "O modelo padrão não pode ser excluído." end

    pr_lib.db.execute('DELETE FROM `forge-crafting-bench-models` WHERE slug = ?', { slug })
    TriggerEvent("forge-crafting:Update")
    return true
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
            model_slug = result[i].model_slug or craftData.model_slug or 'default',
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
            level = someData.level,
            xp = tonumber(someData.xp) or 10
        }
    end
    return send
end)

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

local function getServerItemCount(src, itemName)
    if not src or not itemName then return 0 end
    local searchName = string.lower(tostring(itemName))

    -- 1. Leitura direta dos itens do inventário (ox_inventory:GetInventoryItems)
    if exports.ox_inventory and exports.ox_inventory.GetInventoryItems then
        local ok, invItems = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
        if ok and type(invItems) == "table" then
            local total = 0
            for _, slotData in pairs(invItems) do
                if type(slotData) == "table" then
                    local sName = slotData.name and string.lower(tostring(slotData.name))
                    local sLabel = slotData.label and string.lower(tostring(slotData.label))
                    if sName == searchName or (sLabel and sLabel == searchName) then
                        total = total + (tonumber(slotData.count or slotData.amount) or 1)
                    end
                end
            end
            if total > 0 then return total end

            -- Verificar aliases (ex: ferro <-> iron, metal <-> metalscrap)
            local alias = ITEM_ALIASES[searchName]
            if alias then
                for _, slotData in pairs(invItems) do
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

    -- 2. Tentativa via ox_inventory:GetItemCount export
    if exports.ox_inventory and exports.ox_inventory.GetItemCount then
        local ok, c = pcall(function() return exports.ox_inventory:GetItemCount(src, itemName) end)
        if ok and c and tonumber(c) and tonumber(c) > 0 then return tonumber(c) end

        local alias = ITEM_ALIASES[searchName]
        if alias then
            local okA, cA = pcall(function() return exports.ox_inventory:GetItemCount(src, alias) end)
            if okA and cA and tonumber(cA) and tonumber(cA) > 0 then return tonumber(cA) end
        end
    end

    -- 3. Tentativa via ox_inventory:GetItem com returnsCount=true
    if exports.ox_inventory and exports.ox_inventory.GetItem then
        local ok, c = pcall(function() return exports.ox_inventory:GetItem(src, itemName, nil, true) end)
        if ok and c and tonumber(c) and tonumber(c) > 0 then return tonumber(c) end

        local alias = ITEM_ALIASES[searchName]
        if alias then
            local okA, cA = pcall(function() return exports.ox_inventory:GetItem(src, alias, nil, true) end)
            if okA and cA and tonumber(cA) and tonumber(cA) > 0 then return tonumber(cA) end
        end
    end

    -- 4. Tentativa via pr_lib.inventory
    if pr_lib and pr_lib.inventory and pr_lib.inventory.GetItemCount then
        local ok, c = pcall(function() return pr_lib.inventory.GetItemCount(src, itemName) end)
        if ok and c and tonumber(c) and tonumber(c) > 0 then return tonumber(c) end

        local alias = ITEM_ALIASES[searchName]
        if alias then
            local okA, cA = pcall(function() return pr_lib.inventory.GetItemCount(src, alias) end)
            if okA and cA and tonumber(cA) and tonumber(cA) > 0 then return tonumber(cA) end
        end
    end

    return 0
end

local function removeServerItem(src, itemName, amount)
    amount = tonumber(amount) or 1
    local searchName = string.lower(tostring(itemName))

    -- Determinar se o item está no inventário com o nome original ou alias
    local targetItemName = itemName
    if getServerItemCount(src, itemName) < amount then
        local alias = ITEM_ALIASES[searchName]
        if alias and getServerItemCount(src, alias) >= amount then
            targetItemName = alias
        end
    end

    if exports.ox_inventory and exports.ox_inventory.RemoveItem then
        local ok, res = pcall(function() return exports.ox_inventory:RemoveItem(src, targetItemName, amount) end)
        if ok and res then return true end
    end

    if pr_lib and pr_lib.inventory and pr_lib.inventory.RemoveItem then
        local ok, res = pcall(function() return pr_lib.inventory.RemoveItem(src, targetItemName, amount) end)
        if ok and res then return true end
    end

    return false
end

local COMPONENT_IMAGE_FALLBACKS = {
    at_scope_macro = 'at_scope_small.png',
    at_compensator = 'at_muzzle_tactical.png',
    at_laser = 'at_flashlight.png',
    at_skin_boom = 'boomcamo_attachment.png',
    at_skin_brushstroke = 'brushcamo_attachment.png',
    at_skin_camo = 'digicamo_attachment.png',
    at_skin_geometric = 'geocamo_attachment.png',
    at_skin_leopard = 'leopardcamo_attachment.png',
    at_skin_patriotic = 'patriotcamo_attachment.png',
    at_skin_perseus = 'perseuscamo_attachment.png',
    at_skin_sessanta = 'sessantacamo_attachment.png',
    at_skin_skull = 'skullcamo_attachment.png',
    at_skin_wood = 'woodcamo_attachment.png',
    at_skin_zebra = 'zebracamo_attachment.png',
}

local function oxImageExists(fileName)
    return type(LoadResourceFile) == 'function'
        and fileName
        and LoadResourceFile('ox_inventory', 'web/images/' .. fileName) ~= nil
end

local function buildInventoryImageUrl(fileName)
    if pr_lib and pr_lib.inventory and pr_lib.inventory.getInventoryImg then
        local ok, imageUrl = pcall(function() return pr_lib.inventory.getInventoryImg(fileName) end)
        if ok and imageUrl and imageUrl ~= '' then return imageUrl end
    end
    return 'nui://ox_inventory/web/images/' .. fileName
end

local function resolveServerItemImage(itemName, metadata)
    if not itemName or itemName == "" then return "" end
    if itemName:find("^http") or itemName:find("^nui:") then return itemName end

    if type(metadata) == 'table' then
        local metadataImage = metadata.imageurl or metadata.image
        if metadataImage and metadataImage ~= '' then return tostring(metadataImage) end
    end

    local itemKey = string.lower(tostring(itemName))
    local componentEntry = WeaponComponentsConfig.GetComponentEntry(itemKey)
    if componentEntry and componentEntry.image and componentEntry.image ~= '' then
        local configuredImage = tostring(componentEntry.image)
        if configuredImage:find('^http') or configuredImage:find('^nui:') then return configuredImage end
        if not configuredImage:find('%.%w+$') then configuredImage = configuredImage .. '.png' end
        if oxImageExists(configuredImage) then return buildInventoryImageUrl(configuredImage) end
    end

    -- 1. Consultar ox_inventory:Items para obter a imagem oficial configurada (ex: at_suppressor.png)
    if exports and exports.ox_inventory and exports.ox_inventory.Items then
        local ok, it = pcall(function() return exports.ox_inventory:Items(itemName) end)
        if ok and it then
            local img = it.image or (it.client and it.client.image)
            img = img and tostring(img) or ''
            if img ~= '' then
                if img:find("^http") or img:find("^nui:") then return img end
                if not img:find('%.%w+$') then img = img .. '.png' end
                if oxImageExists(img) then return buildInventoryImageUrl(img) end
            end
        end
    end

    local baseName = tostring(itemName):gsub("%.%w+$", "")
    local searchLower = string.lower(baseName)

    -- Mapear aliases conhecidos (ex: ferro -> iron, metal -> metalscrap, sucata -> metalscrap)
    local mapped = ITEM_ALIASES[searchLower]
    if mapped then
        baseName = mapped
    end

    local exactFile = baseName .. '.png'
    if not oxImageExists(exactFile) then
        local upperFile = string.upper(baseName) .. '.png'
        if oxImageExists(upperFile) then
            exactFile = upperFile
        else
            exactFile = COMPONENT_IMAGE_FALLBACKS[searchLower]
                or ((searchLower:find('^at_skin_') and 'digicamo_attachment.png') or nil)
                or ((searchLower:find('scope') and 'at_scope_small.png') or nil)
                or ((searchLower:find('supp') and 'at_suppressor.png') or nil)
                or ((searchLower:find('flash') and 'at_flashlight.png') or nil)
                or ((searchLower:find('clip') and 'at_clip_extended.png') or nil)
                or exactFile
        end
    end

    return buildInventoryImageUrl(exactFile)
end

local function resolveServerItemLabel(itemName, fallback)
    if fallback and fallback ~= "" and fallback ~= itemName then return fallback end
    if pr_lib and pr_lib.inventory and pr_lib.inventory.Items then
        local ok, it = pcall(function() return pr_lib.inventory.Items(itemName) end)
        if ok and it and (it.label or it.name) then return it.label or it.name end
    end
    return fallback or itemName
end

pr_lib.callback.register("forge-crafting:fetchItemsFromId", function(source, craft_id)
    local result = pr_lib.db.query('SELECT * FROM `forge-crafting-items` WHERE craft_id = ?', { craft_id })
    if not result or type(result) ~= "table" then return {} end

    local send = {}
    for i = 1, #result do
        local someData = result[i]
        local rawRecipe = json.decode(someData.recipe) or {}
        local recipeList = {}

        for _, ing in ipairs(rawRecipe) do
            local ingName = ing.item or ing.name
            local ingCount = getServerItemCount(source, ingName)
            print(string.format('[forge-crafting:server] Jogador %d: ingrediente %s -> estoque: %d', source, tostring(ingName), ingCount))
            local ingLabel = resolveServerItemLabel(ingName, ing.label or ing.item_label)
            local ingImage = (ing.image and ing.image ~= "" and ing.image) or resolveServerItemImage(ingName)

            recipeList[#recipeList + 1] = {
                item = ingName,
                label = ingLabel or ingName,
                amount = tonumber(ing.amount) or 1,
                owned = ingCount,
                currentAmount = ingCount,
                image = ingImage
            }
        end

        local prodLabel = resolveServerItemLabel(someData.item, someData.item_label)
        local prodImage = (someData.image and someData.image ~= "" and someData.image) or resolveServerItemImage(someData.item)

        send[#send + 1] = {
            craft_id = someData.craft_id,
            item = someData.item,
            item_label = prodLabel,
            recipe = recipeList,
            amount = tonumber(someData.amount) or 1,
            time = tonumber(someData.time) or 5,
            xp = tonumber(someData.xp) or 10,
            model = someData.model,
            anim = someData.anim,
            level = tonumber(someData.level) or 0,
            image = prodImage
        }
    end
    local playerLevel, playerXP = getPlayerSkillData(source)
    return send, playerLevel, playerXP
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
            'INSERT INTO `forge-crafting-items` (craft_id, item, item_label, recipe, time, amount, model, anim, level, xp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            {
                data.craft_id,
                data.main_item,
                data.item_label,
                json.encode(data.recipe),
                data.time,
                data.amount,
                data.model,
                data.anim,
                data.level,
                tonumber(data.xp) or 10
            }
        )
    end
end)

local function loadWorkshops()
    workshops = {}

    local modelRows = pr_lib.db.query('SELECT * FROM `forge-crafting-bench-models`', {}) or {}
    local modelMap = {}
    for _, mr in ipairs(modelRows) do
        modelMap[mr.slug] = {
            slug = mr.slug,
            label = mr.label,
            model = mr.model,
            center_offset = safeJsonDecode(mr.center_offset, { x = 0.0, y = 0.0, z = 0.8, w = 0.0 }),
            scale = tonumber(mr.scale) or 1.0,
            anim_dict = mr.anim_dict,
            anim_name = mr.anim_name,
            anim_offset = safeJsonDecode(mr.anim_offset, { x = -0.85, y = 0.0, z = 0.25 }),
            cam_offset = safeJsonDecode(mr.cam_offset, { x = -0.15, y = 0.0, z = 0.65 }),
            weapon_offset = safeJsonDecode(mr.weapon_offset, nil)
        }
    end

    local fallbackModel = modelMap['default'] or {
        slug = 'default',
        label = 'Workbench',
        model = 'xm3_prop_xm3_bench_04b',
        center_offset = { x = -0.05, y = 0.0, z = 0.805, w = 0.0 },
        scale = 1.0,
        anim_dict = 'anim@amb@board_room@diagram_blueprints@',
        anim_name = 'idle_01_amy_skater_01',
        anim_offset = { x = -0.85, y = 0.0, z = 0.25 },
        cam_offset = { x = -0.15, y = 0.0, z = 0.65 },
        weapon_offset = nil
    }

    local result = pr_lib.db.query('SELECT * FROM `forge-crafting`', {})
    if result and type(result) == "table" then
        for i = 1, #result do
            local craftData = safeJsonDecode(result[i].crafting, {})
            local blipData = safeJsonDecode(result[i].blipdata, {})
            local jobsData = safeJsonDecode(result[i].jobs, {})
            local slug = result[i].model_slug or craftData.model_slug or 'default'
            local propCoords = craftData.propcoords or {}
            local heading = tonumber(craftData.heading) or 0.0
            local propModel = craftData.model or (propCoords and propCoords.model) or result[i].model

            -- 1. Se tem slug específico (não default), buscar no map
            local bModel = nil
            if slug and slug ~= 'default' and slug ~= '' then
                bModel = modelMap[slug]
            end

            -- 2. Se não achou pelo slug específico, ou se o modelo do bModel não corresponde ao prop da bancada
            if (not bModel or (propModel and bModel.model and bModel.model:lower() ~= tostring(propModel):lower())) and propModel then
                for _, m in pairs(modelMap) do
                    if m.model and (m.model:lower() == tostring(propModel):lower()) then
                        bModel = m
                        break
                    end
                end
            end

            -- 3. Fallback
            bModel = bModel or modelMap[slug] or modelMap['default'] or fallbackModel
            propModel = propModel or bModel.model

            workshops[#workshops + 1] = {
                id = result[i].craft_id,
                name = result[i].craft_name,
                model = propModel,
                model_slug = bModel.slug or slug,
                bench_model = bModel,
                coords = vector4(propCoords.x or 0.0, propCoords.y or 0.0, propCoords.z or 0.0, heading),
                heading = heading,
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
        local count = getServerItemCount(src, data.item)
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
    local isAuth, authErr = isPlayerAuthorizedForBench(src, bench)
    if not isAuth then
        return false, authErr or locales.insufficient_permission or "Você não possui permissão para usar esta bancada.", nil
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
        local currentCount = getServerItemCount(src, ing.item)
        if currentCount < requiredAmount then
            return false, locales.cannot_craft or "Você não possui todos os itens necessários no inventário.", nil
        end
    end

    local consumedList = {}
    for _, ing in ipairs(recipe) do
        local amount = tonumber(ing.amount) or 1
        removeServerItem(src, ing.item, amount)
        consumedList[#consumedList + 1] = { item = ing.item, amount = amount }
    end

    activeCraftSessions[src] = {
        craft_id = craft_id,
        item = recipeRow.item,
        item_label = recipeRow.item_label or recipeRow.item,
        amount = tonumber(recipeRow.amount) or 1,
        duration = tonumber(recipeRow.time) or 5,
        xp = tonumber(recipeRow.xp) or 10,
        consumed = consumedList,
        benchCoords = benchCoords,
        startTime = GetGameTimer()
    }

    return true, "Fabricação iniciada.", {
        item = recipeRow.item,
        item_label = recipeRow.item_label or recipeRow.item,
        amount = tonumber(recipeRow.amount) or 1,
        time = tonumber(recipeRow.time) or 5,
        xp = tonumber(recipeRow.xp) or 10,
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
    addCraftingSkill(src, session.xp or 10, session.item, session.amount)

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

RegisterNetEvent("forge-crafting:UpdateBenchModel", function(id, modelSlug)
    local src = source
    if not isPlayerAdmin(src) then return end
    local modelRow = pr_lib.db.single('SELECT model FROM `forge-crafting-bench-models` WHERE slug = ?', { modelSlug })
    if not modelRow then return end

    local row = pr_lib.db.single('SELECT crafting FROM `forge-crafting` WHERE craft_id = ?', { id })
    if row then
        local craftData = json.decode(row.crafting) or {}
        craftData.model = modelRow.model
        craftData.model_slug = modelSlug
        pr_lib.db.execute('UPDATE `forge-crafting` SET crafting = ?, model_slug = ? WHERE craft_id = ?', {
            json.encode(craftData),
            modelSlug,
            id
        })
        TriggerEvent("forge-crafting:Update")
        serverNotification(src, locales.main_title or "Crafting", "Modelo da bancada atualizado para: " .. modelSlug, "success")
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
    elseif task == "xp" then
        pr_lib.db.execute('UPDATE `forge-crafting-items` SET xp = ? WHERE craft_id = ? AND item = ?', { tonumber(need_data) or 10, id, item })
        serverNotification(src, locales.main_title, "XP da receita atualizado com sucesso!", "success")
    end
end)

RegisterNetEvent("forge-crafting:KickPlayer", function()
    DropPlayer(source, locales.kick_reason)
end)

-- =====================================================
--  Catálogo Global de Receitas
-- =====================================================

pr_lib.callback.register('forge-crafting:getRecipeCatalog', function(source, filterCategory)
    local query = 'SELECT * FROM `forge-crafting-recipe-catalog`'
    local params = {}
    if filterCategory and filterCategory ~= '' and filterCategory ~= 'all' then
        query = query .. ' WHERE category = ?'
        params[#params + 1] = filterCategory
    end
    query = query .. ' ORDER BY category ASC, item_label ASC'

    local rows = pr_lib.db.query(query, params) or {}
    local catalog = {}
    for _, r in ipairs(rows) do
        catalog[#catalog + 1] = {
            id = r.id,
            item = r.item,
            item_label = r.item_label,
            recipe = safeJsonDecode(r.recipe, {}),
            time = tonumber(r.time) or 5,
            amount = tonumber(r.amount) or 1,
            model = r.model,
            anim = r.anim,
            level = tonumber(r.level) or 0,
            xp = tonumber(r.xp) or 10,
            category = r.category or 'Geral'
        }
    end
    return catalog
end)

pr_lib.callback.register('forge-crafting:saveRecipeToCatalog', function(source, data)
    if not isPlayerAdmin(source) then return false, "Sem permissão." end
    if not data or not data.item or data.item == '' then return false, "Nome do item inválido." end

    local recipeJson = type(data.recipe) == "table" and json.encode(data.recipe) or (data.recipe or "[]")
    local time = tonumber(data.time) or 5
    local amount = tonumber(data.amount) or 1
    local level = tonumber(data.level) or 0
    local xp = tonumber(data.xp) or 10
    local category = data.category or 'Geral'
    local label = data.item_label or data.item

    pr_lib.db.execute([[
        INSERT INTO `forge-crafting-recipe-catalog`
        (`item`, `item_label`, `recipe`, `time`, `amount`, `model`, `anim`, `level`, `xp`, `category`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            `item_label` = VALUES(`item_label`),
            `recipe` = VALUES(`recipe`),
            `time` = VALUES(`time`),
            `amount` = VALUES(`amount`),
            `model` = VALUES(`model`),
            `anim` = VALUES(`anim`),
            `level` = VALUES(`level`),
            `xp` = VALUES(`xp`),
            `category` = VALUES(`category`)
    ]], {
        data.item,
        label,
        recipeJson,
        time,
        amount,
        data.model,
        data.anim,
        level,
        xp,
        category
    })

    return true, "Receita salva no catálogo global com sucesso!"
end)

pr_lib.callback.register('forge-crafting:deleteRecipeFromCatalog', function(source, item)
    if not isPlayerAdmin(source) then return false, "Sem permissão." end
    if not item then return false, "Item inválido." end

    pr_lib.db.execute('DELETE FROM `forge-crafting-recipe-catalog` WHERE item = ?', { item })
    return true, "Receita removida do catálogo global."
end)

pr_lib.callback.register('forge-crafting:linkRecipesToBench', function(source, craft_id, itemNames)
    if not isPlayerAdmin(source) then return false, "Sem permissão." end
    craft_id = tonumber(craft_id)
    if not craft_id or not itemNames or type(itemNames) ~= "table" or #itemNames == 0 then
        return false, "Nenhuma receita selecionada."
    end

    local placeholders = {}
    for i = 1, #itemNames do
        placeholders[#placeholders + 1] = '?'
    end

    local query = string.format(
        'SELECT * FROM `forge-crafting-recipe-catalog` WHERE item IN (%s)',
        table.concat(placeholders, ',')
    )

    local catalogRows = pr_lib.db.query(query, itemNames) or {}
    if #catalogRows == 0 then
        return false, "Nenhuma receita encontrada no catálogo."
    end

    local addedCount = 0
    local updatedCount = 0

    for _, cat in ipairs(catalogRows) do
        local existing = pr_lib.db.single(
            'SELECT craft_id FROM `forge-crafting-items` WHERE craft_id = ? AND item = ?',
            { craft_id, cat.item }
        )

        local recipeJson = type(cat.recipe) == "table" and json.encode(cat.recipe) or cat.recipe

        if existing then
            pr_lib.db.execute([[
                UPDATE `forge-crafting-items`
                SET item_label = ?, recipe = ?, time = ?, amount = ?, model = ?, anim = ?, level = ?, xp = ?
                WHERE craft_id = ? AND item = ?
            ]], {
                cat.item_label,
                recipeJson,
                cat.time,
                cat.amount,
                cat.model,
                cat.anim,
                cat.level,
                cat.xp,
                craft_id,
                cat.item
            })
            updatedCount = updatedCount + 1
        else
            pr_lib.db.insert([[
                INSERT INTO `forge-crafting-items`
                (craft_id, item, item_label, recipe, time, amount, model, anim, level, xp)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                craft_id,
                cat.item,
                cat.item_label,
                recipeJson,
                cat.time,
                cat.amount,
                cat.model,
                cat.anim,
                cat.level,
                cat.xp
            })
            addedCount = addedCount + 1
        end
    end

    TriggerEvent("forge-crafting:Update")
    serverNotification(
        source,
        locales.main_title or "Crafting",
        string.format("%d receita(s) adicionada(s) e %d atualizada(s) nesta bancada!", addedCount, updatedCount),
        "success"
    )

    return true, addedCount, updatedCount
end)

pr_lib.callback.register('forge-crafting:importSharedRecipesToCatalog', function(source)
    if not isPlayerAdmin(source) then return false, "Sem permissão." end
    if ImportSharedRecipesToCatalog then
        local count = ImportSharedRecipesToCatalog(true)
        serverNotification(source, locales.main_title or "Crafting", string.format("%d receitas importadas/atualizadas no catálogo global!", count), "success")
        return true, count
    end
    return false, "Função de importação não disponível."
end)

-- =====================================================
--  Callbacks de Upgrades e Customização de Armas (ox_inventory)
-- =====================================================

pr_lib.callback.register('forge-crafting:getUpgradeData', function(source)
    local src = source
    local playerItems = {}
    if pr_lib and pr_lib.inventory and pr_lib.inventory.GetInventoryItems then
        local ok, inv = pcall(function() return pr_lib.inventory.GetInventoryItems(src) end)
        if ok and type(inv) == "table" then playerItems = inv end
    end
    if #playerItems == 0 and exports.ox_inventory and exports.ox_inventory.GetInventoryItems then
        local ok, inv = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
        if ok and type(inv) == "table" then playerItems = inv end
    end
    if #playerItems == 0 and exports.ox_inventory and exports.ox_inventory.GetPlayerItems then
        local ok, inv = pcall(function() return exports.ox_inventory:GetPlayerItems(src) end)
        if ok and type(inv) == "table" then playerItems = inv end
    end

    local weapons = {}
    local attachments = {}

    for _, item in pairs(playerItems) do
        if type(item) == "table" and item.name then
            local itemNameUpper = string.upper(tostring(item.name))
            local itemNameLower = string.lower(tostring(item.name))

            if itemNameUpper:find('^WEAPON_') then
                local meta = item.metadata or {}
                local compList = {}
                if type(meta.components) == 'table' then
                    for _, c in pairs(meta.components) do
                        compList[#compList + 1] = tostring(c)
                    end
                elseif type(meta.components) == 'string' and meta.components ~= '' then
                    compList[#compList + 1] = meta.components
                end

                weapons[#weapons + 1] = {
                    slot = item.slot,
                    name = item.name,
                    label = item.label or resolveServerItemLabel(item.name, item.name),
                    count = item.count or 1,
                    serial = meta.serial or meta.serie or 'N/A',
                    durability = tonumber(meta.durability) or 100,
                    ammo = tonumber(meta.ammo) or 0,
                    tint = tonumber(meta.tint) or 0,
                    components = compList,
                    metadata = meta,
                    image = resolveServerItemImage(item.name, meta)
                }
            else
                local isAttachment = false
                if WeaponComponentsConfig.ItemToComponents[itemNameLower] or itemNameLower:find('^at_') then
                    isAttachment = true
                else
                    local slotType = WeaponComponentsConfig.GetSlot(itemNameLower)
                    if slotType and slotType ~= 'tint' and (itemNameLower:find('supp') or itemNameLower:find('scope') or itemNameLower:find('flsh') or itemNameLower:find('clip') or itemNameLower:find('grip')) then
                        isAttachment = true
                    end
                end

                if isAttachment then
                    local slotType = WeaponComponentsConfig.GetSlot(itemNameLower)
                    attachments[#attachments + 1] = {
                        slot = item.slot,
                        name = item.name,
                        label = item.label or resolveServerItemLabel(item.name, item.name),
                        count = item.count or 1,
                        slotType = slotType,
                        image = resolveServerItemImage(item.name, item.metadata)
                    }
                end
            end
        end
    end

    return {
        weapons = weapons,
        attachments = attachments,
        tints = WeaponComponentsConfig.Tints or {}
    }
end)

pr_lib.callback.register('forge-crafting:installWeaponComponent', function(source, weaponSlot, componentItem, validatedHash, clientWeaponName)
    local src = source
    weaponSlot = tonumber(weaponSlot)
    if not weaponSlot or not componentItem then
        return false, "Dados inválidos para instalação."
    end

    local weaponItem = nil
    if pr_lib and pr_lib.inventory and pr_lib.inventory.GetSlot then
        local ok, w = pcall(function() return pr_lib.inventory.GetSlot(src, weaponSlot) end)
        if ok and w then weaponItem = w end
    end
    if not weaponItem and exports.ox_inventory and exports.ox_inventory.GetSlot then
        local ok, w = pcall(function() return exports.ox_inventory:GetSlot(src, weaponSlot) end)
        if ok and w then weaponItem = w end
    end
    if not weaponItem and exports.ox_inventory and exports.ox_inventory.GetInventoryItems then
        local ok, inv = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
        if ok and type(inv) == "table" then
            for _, it in pairs(inv) do
                if it.slot == weaponSlot then weaponItem = it; break end
            end
        end
    end

    if not weaponItem or not weaponItem.name or not string.upper(tostring(weaponItem.name)):find('^WEAPON_') then
        return false, "Arma não encontrada no slot especificado."
    end

    if not clientWeaponName or string.upper(tostring(clientWeaponName)) ~= string.upper(tostring(weaponItem.name)) then
        return false, "A arma selecionada mudou. Selecione-a novamente."
    end

    local weaponName = weaponItem.name
    local compHash = WeaponComponentsConfig.ResolveComponentHash(weaponName, componentItem, validatedHash)
    if not compHash then
        return false, "Este componente não é compatível com esta arma."
    end

    local compCount = getServerItemCount(src, componentItem)
    if compCount < 1 then
        return false, "Você não possui este componente no seu inventário."
    end

    local meta = weaponItem.metadata or {}
    local currentComponents = {}
    if type(meta.components) == 'table' then
        for _, c in pairs(meta.components) do
            currentComponents[#currentComponents + 1] = tostring(c)
        end
    elseif type(meta.components) == 'string' and meta.components ~= '' then
        currentComponents[#currentComponents + 1] = meta.components
    end

    local targetSlot = WeaponComponentsConfig.GetSlot(componentItem)
    local removedOldItem = nil
    local filteredComps = {}
    for _, existingComp in ipairs(currentComponents) do
        local existingSlot = WeaponComponentsConfig.GetSlot(existingComp)
        if existingSlot == targetSlot then
            removedOldItem = existingComp
        else
            filteredComps[#filteredComps + 1] = existingComp
        end
    end

    local removedNew = removeServerItem(src, componentItem, 1)
    if not removedNew then
        return false, "Falha ao remover o componente do inventário."
    end

    if removedOldItem then
        if exports.ox_inventory and exports.ox_inventory.AddItem then
            pcall(function() exports.ox_inventory:AddItem(src, removedOldItem, 1) end)
        elseif pr_lib and pr_lib.inventory and pr_lib.inventory.AddItem then
            pcall(function() pr_lib.inventory.AddItem(src, removedOldItem, 1) end)
        end
    end

    filteredComps[#filteredComps + 1] = componentItem
    meta.components = filteredComps

    if exports.ox_inventory and exports.ox_inventory.SetMetadata then
        pcall(function() exports.ox_inventory:SetMetadata(src, weaponSlot, meta) end)
    end

    serverNotification(src, locales.main_title or "Crafting", "Componente acoplado com sucesso!", "success")
    return true, meta, compHash
end)

pr_lib.callback.register('forge-crafting:removeWeaponComponent', function(source, weaponSlot, componentName)
    local src = source
    weaponSlot = tonumber(weaponSlot)
    if not weaponSlot or not componentName then
        return false, "Dados inválidos para remoção."
    end

    local weaponItem = nil
    if pr_lib and pr_lib.inventory and pr_lib.inventory.GetSlot then
        local ok, w = pcall(function() return pr_lib.inventory.GetSlot(src, weaponSlot) end)
        if ok and w then weaponItem = w end
    end
    if not weaponItem and exports.ox_inventory and exports.ox_inventory.GetSlot then
        local ok, w = pcall(function() return exports.ox_inventory:GetSlot(src, weaponSlot) end)
        if ok and w then weaponItem = w end
    end
    if not weaponItem and exports.ox_inventory and exports.ox_inventory.GetInventoryItems then
        local ok, inv = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
        if ok and type(inv) == "table" then
            for _, it in pairs(inv) do
                if it.slot == weaponSlot then weaponItem = it; break end
            end
        end
    end

    if not weaponItem or not weaponItem.name then
        return false, "Arma não encontrada."
    end

    local meta = weaponItem.metadata or {}
    local currentComponents = {}
    if type(meta.components) == 'table' then
        for _, c in pairs(meta.components) do
            currentComponents[#currentComponents + 1] = tostring(c)
        end
    elseif type(meta.components) == 'string' and meta.components ~= '' then
        currentComponents[#currentComponents + 1] = meta.components
    end

    local foundIndex = nil
    local compToReturn = nil
    for idx, c in ipairs(currentComponents) do
        if string.lower(c) == string.lower(componentName) or
           string.lower(WeaponComponentsConfig.GetSlot(c)) == string.lower(componentName) then
            foundIndex = idx
            compToReturn = c
            break
        end
    end

    if not foundIndex then
        return false, "Componente não encontrado nesta arma."
    end

    if exports.ox_inventory and exports.ox_inventory.CanCarryItem then
        local canCarry = exports.ox_inventory:CanCarryItem(src, compToReturn, 1)
        if not canCarry then
            return false, "Inventário cheio! Não é possível desinstalar o componente agora."
        end
    end

    table.remove(currentComponents, foundIndex)
    meta.components = currentComponents

    if exports.ox_inventory and exports.ox_inventory.SetMetadata then
        pcall(function() exports.ox_inventory:SetMetadata(src, weaponSlot, meta) end)
    end

    if exports.ox_inventory and exports.ox_inventory.AddItem then
        pcall(function() exports.ox_inventory:AddItem(src, compToReturn, 1) end)
    elseif pr_lib and pr_lib.inventory and pr_lib.inventory.AddItem then
        pcall(function() pr_lib.inventory.AddItem(src, compToReturn, 1) end)
    end

    local compHash = WeaponComponentsConfig.ResolveComponentHash(weaponItem.name, compToReturn)

    serverNotification(src, locales.main_title or "Crafting", "Componente removido e guardado no inventário.", "inform")
    return true, meta, compHash
end)

pr_lib.callback.register('forge-crafting:setWeaponTint', function(source, weaponSlot, tintIndex)
    local src = source
    weaponSlot = tonumber(weaponSlot)
    tintIndex = tonumber(tintIndex) or 0
    if not weaponSlot then
        return false, "Slot de arma inválido."
    end

    local weaponItem = nil
    if pr_lib and pr_lib.inventory and pr_lib.inventory.GetSlot then
        local ok, w = pcall(function() return pr_lib.inventory.GetSlot(src, weaponSlot) end)
        if ok and w then weaponItem = w end
    end
    if not weaponItem and exports.ox_inventory and exports.ox_inventory.GetSlot then
        local ok, w = pcall(function() return exports.ox_inventory:GetSlot(src, weaponSlot) end)
        if ok and w then weaponItem = w end
    end
    if not weaponItem and exports.ox_inventory and exports.ox_inventory.GetInventoryItems then
        local ok, inv = pcall(function() return exports.ox_inventory:GetInventoryItems(src) end)
        if ok and type(inv) == "table" then
            for _, it in pairs(inv) do
                if it.slot == weaponSlot then weaponItem = it; break end
            end
        end
    end

    if not weaponItem or not weaponItem.name then
        return false, "Arma não encontrada."
    end

    local meta = weaponItem.metadata or {}
    meta.tint = tintIndex

    if exports.ox_inventory and exports.ox_inventory.SetMetadata then
        pcall(function() exports.ox_inventory:SetMetadata(src, weaponSlot, meta) end)
    end

    serverNotification(src, locales.main_title or "Crafting", "Pintura da arma aplicada com sucesso!", "success")
    return true, tintIndex
end)

-- =====================================================
--  Exports do Forge Crafting para Sistemas de Habilidades
-- =====================================================

exports('GetPlayerLevel', function(source)
    if not source then return 1 end
    return getPlayerLevel(source)
end)

exports('GetPlayerXP', function(source)
    if not source then return 0 end
    return getPlayerXP(source)
end)

exports('GetPlayerSkillData', function(source)
    if not source then return 1, 0 end
    return getPlayerSkillData(source)
end)

exports('GetLevelsConfig', function()
    return Config.Levels or {}
end)

exports('GetLevelFromXP', function(xp)
    return Config.GetLevelFromXP and Config.GetLevelFromXP(xp) or 1
end)

exports('GetXPForLevel', function(level)
    return Config.GetXPForLevel and Config.GetXPForLevel(level) or 0
end)

exports('GetNextLevelXP', function(currentLevel)
    return Config.GetNextLevelXP and Config.GetNextLevelXP(currentLevel) or nil
end)

exports('GetItemXP', function(craftId, itemName)
    if not craftId or not itemName then return 10 end
    local row = pr_lib.db.single('SELECT xp FROM `forge-crafting-items` WHERE craft_id = ? AND item = ?', { craftId, itemName })
    return (row and tonumber(row.xp)) or 10
end)

exports('AwardCraftXP', function(source, xpAmount, itemName)
    if not source then return false end
    xpAmount = tonumber(xpAmount) or 10
    addCraftingSkill(source, xpAmount, itemName or "manual_award", 1)
    return true
end)
