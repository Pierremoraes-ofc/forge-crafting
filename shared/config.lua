Config = {}
Config.ImagePath = GetConvar('inventory:imagepath', 'nui://ox_inventory/web/images'):gsub('/+$', '') .. '/'
Config.ReputationResource = 'forge-reputation'
Config.CraftingSkill = 'crafting'
Config.CraftingSkillReward = 10

-- =====================================================
--  Configuração Global de Níveis e Experiência (XP)
-- =====================================================
-- Define o XP necessário para atingir cada nível de Crafting.
-- O script consulta o XP do jogador para calcular o nível atual e
-- desbloquear os itens correspondentes na bancada (ex: Carabina MK2 no Nível 2).
Config.Levels = {
    [1] = 0,        -- Nível 1: Inicial (0 XP)
    [2] = 500,      -- Nível 2: 500 XP (ex: libera Carabina MK2)
    [3] = 1500,     -- Nível 3: 1500 XP
    [4] = 3500,     -- Nível 4: 3500 XP
    [5] = 7000,     -- Nível 5: 7000 XP
    [6] = 12000,    -- Nível 6: 12000 XP
    [7] = 20000,    -- Nível 7: 20000 XP
    [8] = 35000,    -- Nível 8: 35000 XP
    [9] = 60000,    -- Nível 9: 60000 XP
    [10] = 100000,  -- Nível 10: 100000 XP
}

--- Retorna o nível de Crafting correspondente a uma quantidade de XP
function Config.GetLevelFromXP(xp)
    xp = tonumber(xp) or 0
    local currentLevel = 1
    local maxLevel = 1
    for lvl, _ in pairs(Config.Levels) do
        if type(lvl) == 'number' and lvl > maxLevel then
            maxLevel = lvl
        end
    end

    for lvl = 1, maxLevel do
        local reqXP = Config.Levels[lvl]
        if reqXP and xp >= reqXP then
            currentLevel = lvl
        else
            break
        end
    end
    return currentLevel
end

--- Retorna o XP necessário para atingir determinado nível
function Config.GetXPForLevel(level)
    level = tonumber(level) or 1
    return Config.Levels[level] or 0
end

--- Retorna o XP necessário para o próximo nível
function Config.GetNextLevelXP(currentLevel)
    currentLevel = tonumber(currentLevel) or 1
    return Config.Levels[currentLevel + 1] or nil
end

-- =====================================================
--  Integração com Script de Skills Externo
-- =====================================================
-- Defina aqui os exports do seu script de skills para:
-- 1. Consultar o nível ou XP atual do jogador
-- 2. Enviar o XP e nível que o jogador ganha ao fabricar itens
Config.SkillsSystem = {
    -- Habilita o uso de exports com o script de skills externo
    enabled = true,

    -- Nome identificador da skill (ex: 'crafting', 'forge', 'fabricacao')
    skillName = 'crafting',

    -- ==============================================================================
    -- CAMPO 1: EXPORT PARA CONSULTAR O NÍVEL ATUAL DO JOGADOR
    -- ==============================================================================
    -- Esta função é chamada para obter o nível do jogador na bancada.
    -- É chamada no SERVER (source = ID do jogador) e no CLIENT (source = nil).
    --
    -- Retornos aceitos:
    --   - Número do nível: return 2
    --   - Tabela: return { level = 2, xp = 520 }
    --   - XP acumulado: return 520 (o forge-crafting calcula o nível via Config.GetLevelFromXP)
    --   - nil (se retornar nil, o forge-crafting usará o banco interno com a tabela de XP)
    -- ==============================================================================
    getCurrentSkill = function(source, skillName)
        skillName = skillName or 'crafting'

        -- >>> COLOQUE AQUI O SEU EXPORT DE CONSULTA <<<
        -- Exemplo Server:
        -- if source then
        --     return exports['meu_script_skills']:GetPlayerSkill(source, skillName)
        -- else
        --     return exports['meu_script_skills']:GetSkillLevel(skillName)
        -- end

        -- Fallback automático caso use forge-reputation:
        local repRes = Config.ReputationResource or 'forge-reputation'
        if GetResourceState(repRes) == 'started' then
            local ok, res = pcall(function()
                if source then
                    return exports[repRes]:getCurrentLevel(source, skillName)
                else
                    return exports[repRes]:getCurrentLevel(skillName)
                end
            end)
            if ok and res ~= nil then return res end
        end

        return nil
    end,

    -- ==============================================================================
    -- CAMPO 2: EXPORT PARA ENVIAR O XP E NÍVEL QUE O PLAYER ESTÁ GANHANDO
    -- ==============================================================================
    -- Chamado no SERVER toda vez que o jogador finaliza a fabricação de um item.
    --
    -- Parâmetros:
    --   source: (number) ID do jogador no servidor
    --   xpGained: (number) Quantidade de XP concedida pela receita fabricada
    --   newLevel: (number) Nível atualizado do jogador com base no XP
    --   totalXP: (number) XP total acumulado do jogador
    --   skillName: (string) Nome da habilidade ('crafting')
    -- ==============================================================================
    addSkillXP = function(source, xpGained, newLevel, totalXP, skillName)
        skillName = skillName or 'crafting'

        -- >>> COLOQUE AQUI O SEU EXPORT DE SALVAMENTO/ENVIO <<<
        -- Exemplo 1: Adicionar XP no seu script:
        -- exports['meu_script_skills']:AddSkillXP(source, skillName, xpGained)
        --
        -- Exemplo 2: Salvar o novo nível no seu script:
        -- exports['meu_script_skills']:SetSkillLevel(source, skillName, newLevel)
        --
        -- Exemplo 3: Salvar XP e Nível juntos:
        -- exports['meu_script_skills']:UpdatePlayerSkill(source, skillName, xpGained, newLevel)

        -- Fallback automático caso use forge-reputation:
        local repRes = Config.ReputationResource or 'forge-reputation'
        if GetResourceState(repRes) == 'started' then
            pcall(function()
                exports[repRes]:updateSkill(source, skillName, xpGained)
            end)
        end
    end,
}

Config.Authorization = {
    ['admin'] = true,
    ['god'] = true,
}

Config.Pfx = "craft:"
Config.CreateTableCommand = 'create'
Config.EditMenuCommand = 'edit'
Config.Debug = false

-- Configurações da Tela de Repouso da Bancada (Passiva com Logo)
Config.StandbyLogo = 'https://i.ibb.co/sphpgQs6/forge-flame.png'
Config.StandbyTitle = 'FORGE CRAFTING'
Config.StandbySubtitle = 'BANCADA DE TRABALHO'
