-- =====================================================
--  Forge Crafting - Definições de Componentes de Armas
--  Mapeamento de Acessórios, Slots e GTA V Component Hashes
-- =====================================================

WeaponComponentsConfig = {}

-- Tipos de Slots Oficiais
WeaponComponentsConfig.Slots = {
    suppressor = { id = 'suppressor', label = 'Cano / Silenciador', order = 1 },
    scope      = { id = 'scope',      label = 'Mira / Óptica',       order = 2 },
    flashlight = { id = 'flashlight', label = 'Lanterna / Tático',   order = 3 },
    magazine   = { id = 'magazine',   label = 'Carregador / Pente',  order = 4 },
    grip       = { id = 'grip',       label = 'Empunhadura / Grip',  order = 5 },
    tint       = { id = 'tint',       label = 'Pintura / Skin',      order = 6 }
}

-- Lista de Tints Nativos do GTA V
WeaponComponentsConfig.Tints = {
    { id = 0, label = 'Padrão / Original', color = '#64748b' },
    { id = 1, label = 'Verde Militar',      color = '#22c55e' },
    { id = 2, label = 'Ouro Luxo',          color = '#eab308' },
    { id = 3, label = 'Rosa Chiclete',      color = '#ec4899' },
    { id = 4, label = 'Camuflagem Urbana',  color = '#94a3b8' },
    { id = 5, label = 'Policial LSPD',      color = '#3b82f6' },
    { id = 6, label = 'Laranja Tático',     color = '#f97316' },
    { id = 7, label = 'Platina Cromo',      color = '#e2e8f0' }
}

-- Mapeamento abrangente de itens do ox_inventory / nomes comuns para GTA V Components
WeaponComponentsConfig.ItemToComponents = {
    -- Silenciadores / Supressores
    ['at_suppressor_heavy'] = {
        'COMPONENT_AT_AR_SUPP',
        'COMPONENT_AT_AR_SUPP_02',
        'COMPONENT_AT_SR_SUPP',
        'COMPONENT_AT_SR_SUPP_03'
    },
    ['at_suppressor_light'] = {
        'COMPONENT_AT_PI_SUPP',
        'COMPONENT_AT_PI_SUPP_02'
    },
    ['at_suppressor'] = {
        'COMPONENT_AT_PI_SUPP',
        'COMPONENT_AT_PI_SUPP_02',
        'COMPONENT_AT_AR_SUPP',
        'COMPONENT_AT_AR_SUPP_02',
        'COMPONENT_AT_SR_SUPP'
    },

    -- Lanternas e Lasers
    ['at_flashlight'] = {
        'COMPONENT_AT_PI_FLSH',
        'COMPONENT_AT_PI_FLSH_02',
        'COMPONENT_AT_PI_FLSH_03',
        'COMPONENT_AT_AR_FLSH'
    },
    ['at_laser'] = {
        'COMPONENT_AT_PI_FLSH',
        'COMPONENT_AT_AR_FLSH'
    },

    -- Miras e Ópticas
    ['at_scope_advanced'] = {
        'COMPONENT_AT_SCOPE_MAX'
    },
    ['at_scope_macro'] = {
        'COMPONENT_AT_SCOPE_MACRO',
        'COMPONENT_AT_SCOPE_MACRO_02',
        'COMPONENT_AT_SCOPE_MACRO_MK2',
        'COMPONENT_AT_SCOPE_MACRO_02_MK2',
        'COMPONENT_AT_SCOPE_MACRO_02_SMG_MK2'
    },
    ['at_scope_small'] = {
        'COMPONENT_AT_SCOPE_SMALL',
        'COMPONENT_AT_SCOPE_SMALL_02',
        'COMPONENT_AT_SCOPE_SMALL_MK2',
        'COMPONENT_AT_SCOPE_SMALL_SMG_MK2'
    },
    ['at_scope_medium'] = {
        'COMPONENT_AT_SCOPE_MEDIUM',
        'COMPONENT_AT_SCOPE_MEDIUM_MK2'
    },
    ['at_scope_large'] = {
        'COMPONENT_AT_SCOPE_LARGE',
        'COMPONENT_AT_SCOPE_LARGE_MK2'
    },
    ['at_scope_holo'] = {
        'COMPONENT_AT_SIGHTS',
        'COMPONENT_AT_SIGHTS_SMG',
        'COMPONENT_AT_PI_RAIL',
        'COMPONENT_AT_PI_RAIL_02',
        'COMPONENT_AT_SCOPE_MACRO',
        'COMPONENT_AT_SCOPE_SMALL'
    },

    -- Pinturas e Kits de Camuflagem
    ['at_skin_camo'] = {
        'COMPONENT_CARBINERIFLE_MK2_CAMO',
        'COMPONENT_ASSAULTRIFLE_MK2_CAMO',
        'COMPONENT_SPECIALCARBINE_MK2_CAMO',
        'COMPONENT_BULLPUPRIFLE_MK2_CAMO',
        'COMPONENT_SMG_MK2_CAMO',
        'COMPONENT_PISTOL_MK2_CAMO',
        'COMPONENT_SNSPISTOL_MK2_CAMO',
        'COMPONENT_REVOLVER_MK2_CAMO',
        'COMPONENT_PUMPSHOTGUN_MK2_CAMO',
        'COMPONENT_HEAVYSNIPER_MK2_CAMO',
        'COMPONENT_MARKSMANRIFLE_MK2_CAMO',
        'COMPONENT_COMBATMG_MK2_CAMO'
    },

    -- Pentes e Carregadores Estendidos
    ['at_clip_extended_pistol'] = {
        'COMPONENT_PISTOL_CLIP_02',
        'COMPONENT_COMBATPISTOL_CLIP_02',
        'COMPONENT_APPISTOL_CLIP_02',
        'COMPONENT_PISTOL50_CLIP_02',
        'COMPONENT_HEAVYPISTOL_CLIP_02',
        'COMPONENT_VINTAGEPISTOL_CLIP_02',
        'COMPONENT_SNSPISTOL_CLIP_02',
        'COMPONENT_PISTOL_MK2_CLIP_02'
    },
    ['at_clip_extended_smg'] = {
        'COMPONENT_MICROSMG_CLIP_02',
        'COMPONENT_SMG_CLIP_02',
        'COMPONENT_ASSAULTSMG_CLIP_02',
        'COMPONENT_COMBATPDW_CLIP_02',
        'COMPONENT_MACHINEPISTOL_CLIP_02',
        'COMPONENT_MINISMG_CLIP_02',
        'COMPONENT_SMG_MK2_CLIP_02'
    },
    ['at_clip_extended_rifle'] = {
        'COMPONENT_ASSAULTRIFLE_CLIP_02',
        'COMPONENT_CARBINERIFLE_CLIP_02',
        'COMPONENT_ADVANCEDRIFLE_CLIP_02',
        'COMPONENT_SPECIALCARBINE_CLIP_02',
        'COMPONENT_BULLPUPRIFLE_CLIP_02',
        'COMPONENT_COMPACTRIFLE_CLIP_02',
        'COMPONENT_ASSAULTRIFLE_MK2_CLIP_02',
        'COMPONENT_CARBINERIFLE_MK2_CLIP_02',
        'COMPONENT_SPECIALCARBINE_MK2_CLIP_02',
        'COMPONENT_BULLPUPRIFLE_MK2_CLIP_02',
        'COMPONENT_HEAVYRIFLE_CLIP_02',
        'COMPONENT_MILITARYRIFLE_CLIP_02',
        'COMPONENT_TACTICALRIFLE_CLIP_02'
    },
    ['at_clip_drum_rifle'] = {
        'COMPONENT_ASSAULTRIFLE_CLIP_03',
        'COMPONENT_CARBINERIFLE_CLIP_03',
        'COMPONENT_SPECIALCARBINE_CLIP_03',
        'COMPONENT_COMPACTRIFLE_CLIP_03'
    },
    ['at_clip_extended_shotgun'] = {
        'COMPONENT_HEAVYSHOTGUN_CLIP_02',
        'COMPONENT_ASSAULTSHOTGUN_CLIP_02'
    },

    -- Empunhaduras (Grips)
    ['at_grip'] = {
        'COMPONENT_AT_AR_AFGRIP',
        'COMPONENT_AT_AR_AFGRIP_02'
    },
    ['at_barrel'] = {
        'COMPONENT_AT_AR_BARREL_01',
        'COMPONENT_AT_AR_BARREL_02',
        'COMPONENT_AT_SR_BARREL_01',
        'COMPONENT_AT_SR_BARREL_02'
    }
}

-- O catálogo autoritativo dos itens de arma fica no forge-core e é o mesmo
-- consumido pelo ox_inventory. Carregar esses dados aqui evita manter duas
-- listas divergentes de componentes, tipos e imagens.
WeaponComponentsConfig.ComponentCatalog = {}

local componentTypeToSlot = {
    barrel = 'suppressor',
    muzzle = 'suppressor',
    suppressor = 'suppressor',
    sight = 'scope',
    scope = 'scope',
    flashlight = 'flashlight',
    laser = 'flashlight',
    magazine = 'magazine',
    clip = 'magazine',
    grip = 'grip',
    skin = 'tint',
    tint = 'tint',
}

local function normalizeComponentList(value)
    if type(value) == 'string' and value ~= '' then return { value } end
    if type(value) ~= 'table' then return {} end

    local result = {}
    for _, componentName in pairs(value) do
        if type(componentName) == 'string' and componentName ~= '' then
            result[#result + 1] = componentName
        end
    end
    return result
end

local function loadForgeComponentCatalog()
    if type(LoadResourceFile) ~= 'function' or not json or type(json.decode) ~= 'function' then return end

    local raw = LoadResourceFile('forge-core', 'data/weapon_inventory.json')
    if not raw or raw == '' then return end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return end

    local components = decoded.components or decoded.Components
    if type(components) ~= 'table' then return end

    for itemName, entry in pairs(components) do
        if type(entry) == 'table' and entry.active ~= false then
            local key = string.lower(tostring(itemName))
            local clientData = type(entry.client) == 'table' and entry.client or {}
            local candidates = normalizeComponentList(clientData.component or entry.component)
            local componentType = string.lower(tostring(entry.type or ''))

            WeaponComponentsConfig.ComponentCatalog[key] = {
                label = entry.label or itemName,
                image = clientData.image or entry.image,
                slot = componentTypeToSlot[componentType],
                components = candidates,
            }

            if #candidates > 0 then
                WeaponComponentsConfig.ItemToComponents[key] = candidates
            end
        end
    end
end

loadForgeComponentCatalog()

function WeaponComponentsConfig.GetComponentEntry(identifier)
    if not identifier then return nil end
    return WeaponComponentsConfig.ComponentCatalog[string.lower(tostring(identifier))]
end

function WeaponComponentsConfig.GetComponentCandidates(identifier)
    if not identifier then return {} end
    local key = string.lower(tostring(identifier))
    local entry = WeaponComponentsConfig.ComponentCatalog[key]
    if entry and type(entry.components) == 'table' and #entry.components > 0 then
        return entry.components
    end
    return WeaponComponentsConfig.ItemToComponents[key] or {}
end

local function normalizeHash(value)
    local numberValue = tonumber(value)
    if not numberValue then return nil end
    if numberValue < 0 then numberValue = numberValue + 4294967296 end
    return numberValue
end

function WeaponComponentsConfig.IsCandidateHash(identifier, componentHash)
    local wantedHash = normalizeHash(componentHash)
    if not wantedHash then return false end

    local text = tostring(identifier or '')
    if string.upper(text):find('^COMPONENT_') then
        local directHash = (joaat and joaat(string.upper(text))) or GetHashKey(string.upper(text))
        return normalizeHash(directHash) == wantedHash
    end

    for _, componentName in ipairs(WeaponComponentsConfig.GetComponentCandidates(identifier)) do
        local candidateHash = (joaat and joaat(componentName)) or GetHashKey(componentName)
        if normalizeHash(candidateHash) == wantedHash then return true end
    end
    return false
end

--- Retorna o slot ('suppressor', 'scope', etc.) para qualquer nome de item ou componente
function WeaponComponentsConfig.GetSlot(identifier)
    if not identifier then return 'suppressor' end
    local str = string.lower(tostring(identifier))

    local catalogEntry = WeaponComponentsConfig.ComponentCatalog[str]
    if catalogEntry and catalogEntry.slot then return catalogEntry.slot end

    if str:find('supp') or str:find('silenc') or str:find('barrel') or str:find('muzzle') or str:find('compensator') then
        return 'suppressor'
    elseif str:find('scope') or str:find('sight') or str:find('optic') or str:find('holo') or str:find('mira') then
        return 'scope'
    elseif str:find('flsh') or str:find('flash') or str:find('laser') or str:find('lanterna') or str:find('tactical') then
        return 'flashlight'
    elseif str:find('clip') or str:find('mag') or str:find('drum') or str:find('pente') or str:find('carregador') then
        return 'magazine'
    elseif str:find('grip') or str:find('afgrip') or str:find('handle') or str:find('empunhadura') then
        return 'grip'
    elseif str:find('tint') or str:find('skin') or str:find('camo') or str:find('pintura') then
        return 'tint'
    end

    return 'suppressor'
end

--- Retorna o hash nativo GTA V compatível com a arma para um determinado item
function WeaponComponentsConfig.ResolveComponentHash(weaponName, itemOrComp, validatedHash)
    if not weaponName or not itemOrComp then return nil end

    local weaponHash = type(weaponName) == 'number' and weaponName or ((joaat and joaat(string.upper(tostring(weaponName)))) or GetHashKey(string.upper(tostring(weaponName))))
    local itemKey = string.lower(tostring(itemOrComp))
    local isClient = not (IsDuplicityVersion and IsDuplicityVersion())

    -- O native de compatibilidade existe apenas no cliente. O servidor aceita
    -- somente um hash que o cliente validou e que também pertença à lista
    -- autoritativa do item, impedindo a troca por um componente arbitrário.
    if validatedHash and WeaponComponentsConfig.IsCandidateHash(itemOrComp, validatedHash) then
        local checkedHash = tonumber(validatedHash)
        if isClient then
            if DoesWeaponTakeWeaponComponent and DoesWeaponTakeWeaponComponent(weaponHash, checkedHash) then
                return checkedHash
            end
        else
            return checkedHash
        end
    end

    -- Sem o hash validado pelo native do cliente o servidor não tenta adivinhar.
    if not isClient then return nil end

    -- 1. Se já for o nome direto do componente GTA V (ex: COMPONENT_AT_AR_SUPP)
    local directHash = (joaat and joaat(string.upper(tostring(itemOrComp)))) or GetHashKey(string.upper(tostring(itemOrComp)))
    if isClient then
        if DoesWeaponTakeWeaponComponent and DoesWeaponTakeWeaponComponent(weaponHash, directHash) then
            return directHash
        end
    end

    -- 2. Consultar diretamente ox_inventory:Items (se disponível)
    if exports and exports.ox_inventory and exports.ox_inventory.Items then
        local ok, it = pcall(function() return exports.ox_inventory:Items(itemKey) end)
        if ok and it and it.client and it.client.component then
            local compList = type(it.client.component) == 'table' and it.client.component or { it.client.component }
            if isClient then
                for _, compStr in ipairs(compList) do
                    local h = (joaat and joaat(compStr)) or GetHashKey(compStr)
                    if DoesWeaponTakeWeaponComponent and DoesWeaponTakeWeaponComponent(weaponHash, h) then
                        return h
                    end
                end
            end
        end
    end

    -- 3. Buscar no mapeamento pré-configurado
    local candidates = WeaponComponentsConfig.GetComponentCandidates(itemKey)
    if candidates then
        if isClient then
            for _, compStr in ipairs(candidates) do
                local h = (joaat and joaat(compStr)) or GetHashKey(compStr)
                if DoesWeaponTakeWeaponComponent and DoesWeaponTakeWeaponComponent(weaponHash, h) then
                    return h
                end
            end
        end
    end

    -- Nenhum candidato passou no native de compatibilidade.
    return nil
end
