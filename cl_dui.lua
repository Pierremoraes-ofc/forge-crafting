-- =====================================================
--  Forge Crafting - Módulo de Renderização DUI via pr_bridge
--  Utiliza pr_lib.fivem.dui para renderização 3D poligonal
-- =====================================================

local DUI_WIDTH = 1680
local DUI_HEIGHT = 700

local currentActiveSession = nil
local passiveScreens = {} -- DUI screens para bancadas próximas

-- =====================================================
--  Funções Matemáticas Utilitárias
-- =====================================================

local function degToRad(degrees)
    degrees = tonumber(degrees) or 0.0
    return degrees * math.pi / 180.0
end

local function getRelativeOffset(baseCoordsOrEntity, headingDeg, offset)
    local baseCoords = baseCoordsOrEntity
    if type(baseCoordsOrEntity) == "number" and DoesEntityExist(baseCoordsOrEntity) then
        baseCoords = GetEntityCoords(baseCoordsOrEntity)
        headingDeg = GetEntityHeading(baseCoordsOrEntity)
    end
    baseCoords = baseCoords or vector3(0.0, 0.0, 0.0)
    headingDeg = tonumber(headingDeg) or 0.0
    local headingRad = degToRad(headingDeg)
    local cosH = math.cos(headingRad)
    local sinH = math.sin(headingRad)

    offset = offset or { x = 0.0, y = 0.0, z = 0.0 }
    local rx = (offset.x or 0.0) * cosH - (offset.y or 0.0) * sinH
    local ry = (offset.x or 0.0) * sinH + (offset.y or 0.0) * cosH

    return vector3(baseCoords.x + rx, baseCoords.y + ry, baseCoords.z + (offset.z or 0.0))
end

local function reverseRelativeOffset(baseCoordsOrEntity, headingDeg, worldCoords)
    local baseCoords = baseCoordsOrEntity
    if type(baseCoordsOrEntity) == "number" and DoesEntityExist(baseCoordsOrEntity) then
        baseCoords = GetEntityCoords(baseCoordsOrEntity)
        headingDeg = GetEntityHeading(baseCoordsOrEntity)
    end
    baseCoords = baseCoords or vector3(0.0, 0.0, 0.0)
    headingDeg = tonumber(headingDeg) or 0.0
    local headingRad = degToRad(headingDeg)
    local cosH = math.cos(headingRad)
    local sinH = math.sin(headingRad)

    local dx = worldCoords.x - baseCoords.x
    local dy = worldCoords.y - baseCoords.y

    local rx = dx * cosH + dy * sinH
    local ry = -dx * sinH + dy * cosH

    return vector3(rx, ry, worldCoords.z - baseCoords.z)
end
-- =====================================================
--  Mapeamento de Coordenadas do Cursor para a DUI
--  Projeta o raio da câmera sobre o plano 3D da bancada
-- =====================================================

local function vec3Cross(a, b)
    return vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
end

local function vec3Dot(a, b)
    return a.x * b.x + a.y * b.y + a.z * b.z
end

local function rotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local pitch = math.abs(math.cos(x))

    return vector3(
        -math.sin(z) * pitch,
        math.cos(z) * pitch,
        math.sin(x)
    )
end

local function getCameraRay(camera)
    local screenW, screenH = GetActiveScreenResolution()
    local cursorX, cursorY = GetNuiCursorPosition()

    local normX = 0.5
    local normY = 0.5
    if cursorX and cursorY and screenW and screenH and screenW > 0 and screenH > 0 then
        normX = cursorX / screenW
        normY = cursorY / screenH
    end

    local camCoords = GetCamCoord(camera)
    local camRot = GetCamRot(camera, 2)
    local camFov = GetCamFov(camera) or 50.0

    local forward = rotationToDirection(camRot)
    local upBase = vector3(0.0, 0.0, 1.0)
    local right = vec3Cross(forward, upBase)
    local rightLen = #(right)
    if rightLen > 0.001 then
        right = right / rightLen
    else
        right = vector3(1.0, 0.0, 0.0)
    end
    local up = vec3Cross(right, forward)
    local upLen = #(up)
    if upLen > 0.001 then
        up = up / upLen
    else
        up = vector3(0.0, 0.0, 1.0)
    end

    local tanHalfFov = math.tan(math.rad(camFov * 0.5))
    local aspect = screenW / math.max(1, screenH)

    local screenOffsetX = (normX - 0.5) * 2.0 * tanHalfFov * aspect
    local screenOffsetY = -(normY - 0.5) * 2.0 * tanHalfFov

    local rayDir = forward + right * screenOffsetX + up * screenOffsetY
    local rayDirLen = #(rayDir)
    if rayDirLen > 0.001 then
        rayDir = rayDir / rayDirLen
    end

    return camCoords, rayDir
end

local function mapRayToDui(camCoords, rayDir, p1, p2, p3, p4)
    local u = p2 - p1 -- Top-Left -> Top-Right (largura)
    local v = p4 - p1 -- Top-Left -> Bottom-Left (altura)

    local normal = vec3Cross(u, v)
    local normLen = #(normal)
    if normLen < 0.0001 then return 0.5, 0.5 end
    normal = normal / normLen

    local denom = vec3Dot(rayDir, normal)
    if math.abs(denom) < 0.0001 then
        return 0.5, 0.5
    end

    local t = vec3Dot(p1 - camCoords, normal) / denom
    if t < 0.0 then
        return 0.5, 0.5
    end

    local hit = camCoords + rayDir * t
    local d = hit - p1

    local uLenSq = vec3Dot(u, u)
    local vLenSq = vec3Dot(v, v)
    if uLenSq < 0.0001 or vLenSq < 0.0001 then return 0.5, 0.5 end

    local relX = vec3Dot(d, u) / uLenSq
    local relY = vec3Dot(d, v) / vLenSq

    -- Clamping seguro [0.0, 1.0]
    if relX < 0.0 then relX = 0.0 elseif relX > 1.0 then relX = 1.0 end
    if relY < 0.0 then relY = 0.0 elseif relY > 1.0 then relY = 1.0 end

    return relX, relY
end
-- =====================================================
--  Acesso à API DUI do pr_bridge
-- =====================================================

local duiApi = nil

local function getDuiApi()
    if duiApi then return duiApi end
    duiApi = (pr_lib and pr_lib.dui) or (pr_lib and pr_lib.fivem and pr_lib.fivem.dui)
    return duiApi
end

local function getDuiUrl()
    local api = getDuiApi()
    if api and api.nuiUrl then
        return api.nuiUrl("html/index.html", GetCurrentResourceName())
    end
    return ("nui://%s/html/index.html"):format(GetCurrentResourceName())
end

-- =====================================================
--  Cálculo dos 4 pontos do polígono DUI na bancada
-- =====================================================

local function calculateBenchPolyPoints(benchBaseCoords, heading, bModel)
    local cOffset = bModel.center_offset or { x = 0.0, y = 0.0, z = 0.85, w = 0.0 }
    local hOffset = tonumber(cOffset.height_offset) or 0.035
    local scale = tonumber(bModel.scale) or 1.0

    -- Se temos 4 vértices calibrados, usar eles
    if cOffset.vertices and #cOffset.vertices == 4 then
        local v1 = getRelativeOffset(benchBaseCoords, heading, cOffset.vertices[1])
        local v2 = getRelativeOffset(benchBaseCoords, heading, cOffset.vertices[2])
        local v3 = getRelativeOffset(benchBaseCoords, heading, cOffset.vertices[3])
        local v4 = getRelativeOffset(benchBaseCoords, heading, cOffset.vertices[4])

        -- Detectar se os pontos 3 e 4 foram salvos invertidos (vetor inferior oposto ao superior)
        -- v1=Top-Left, v2=Top-Right, v3=Bottom-Right, v4=Bottom-Left
        local topDir = v2 - v1
        local bottomDir = v3 - v4
        if (topDir.x * bottomDir.x + topDir.y * bottomDir.y) < 0 then
            v3, v4 = v4, v3
        end

        -- Aplicar offset de altura na normal do polígono
        local horizontal = v2 - v1
        local vertical = v4 - v1
        local normal = vector3(
            horizontal.y * vertical.z - horizontal.z * vertical.y,
            horizontal.z * vertical.x - horizontal.x * vertical.z,
            horizontal.x * vertical.y - horizontal.y * vertical.x
        )
        if normal.z < 0 then
            normal = -normal
        end
        local length = #(normal)
        if length > 0.001 then
            normal = normal / length * hOffset
        else
            normal = vector3(0.0, 0.0, hOffset)
        end

        return v1 + normal, v2 + normal, v3 + normal, v4 + normal
    end

    -- Caso contrário, gerar 4 pontos a partir de center_offset + escala
    local centerCoords = getRelativeOffset(benchBaseCoords, heading, cOffset) + vector3(0.0, 0.0, hOffset)
    local headingRad = degToRad(heading)
    local forward = vector3(-math.sin(headingRad), math.cos(headingRad), 0.0)
    local right = vector3(math.cos(headingRad), math.sin(headingRad), 0.0)

    local halfW = 0.55 * scale
    local halfH = 0.23 * scale

    local p1 = centerCoords - right * halfW + forward * halfH -- Top-Left
    local p2 = centerCoords + right * halfW + forward * halfH -- Top-Right
    local p3 = centerCoords + right * halfW - forward * halfH -- Bottom-Right
    local p4 = centerCoords - right * halfW - forward * halfH -- Bottom-Left

    return p1, p2, p3, p4
end

-- =====================================================
--  Renderização Passiva - DUI em bancadas próximas
-- =====================================================

local function getPassiveScreenId(benchId)
    return ('forge_crafting_passive_%s'):format(tostring(benchId))
end

local function createPassiveScreen(bench)
    local api = getDuiApi()
    if not api then return nil end

    local bModel = bench.bench_model or {}
    local heading = bench.heading or (bench.coords and (bench.coords.w or bench.coords.heading)) or 0.0
    heading = tonumber(heading) or 0.0
    local benchBaseCoords = vector3(bench.coords.x, bench.coords.y, bench.coords.z)
    local p1, p2, p3, p4 = calculateBenchPolyPoints(benchBaseCoords, heading, bModel)

    local screenId = getPassiveScreenId(bench.id)

    local screen, err = api.createPoly({
        id = screenId,
        url = getDuiUrl(),
        width = DUI_WIDTH,
        height = DUI_HEIGHT,
        p1 = p1,
        p2 = p2,
        p3 = p3,
        p4 = p4,
        renderDistance = 14.0,
        color = { 255, 255, 255, 255 },
        mouse = false,
    })

    if screen then
        -- Enviar tela de repouso (somente o Logo da Forge e estilo minimalista)
        CreateThread(function()
            Wait(400)
            if screen and type(screen.send) == 'function' then
                local currentTheme = (GetCurrentTheme and GetCurrentTheme()) or {}
                screen:send({
                    action = 'standby',
                    logo = currentTheme.logo or (Config and Config.StandbyLogo) or 'https://i.ibb.co/sphpgQs6/forge-flame.png',
                    title = currentTheme.title or (Config and Config.StandbyTitle) or 'FORGE CRAFTING',
                    subtitle = currentTheme.subtitle or (Config and Config.StandbySubtitle) or 'BANCADA DE TRABALHO',
                    theme = currentTheme,
                    bench = {
                        id = bench.id,
                        name = bench.name,
                    }
                })
            end
        end)
    end

    return screen
end

function UpdateThemeOnAllScreens(theme)
    theme = theme or (GetCurrentTheme and GetCurrentTheme()) or {}
    for benchId, screen in pairs(passiveScreens) do
        if screen and type(screen.send) == 'function' then
            screen:send({
                action = 'standby',
                logo = theme.logo or (Config and Config.StandbyLogo) or 'https://i.ibb.co/sphpgQs6/forge-flame.png',
                title = theme.title or (Config and Config.StandbyTitle) or 'FORGE CRAFTING',
                subtitle = theme.subtitle or (Config and Config.StandbySubtitle) or 'BANCADA DE TRABALHO',
                theme = theme
            })
        end
    end

    if currentActiveSession and currentActiveSession.screen and type(currentActiveSession.screen.send) == 'function' then
        currentActiveSession.screen:send({
            action = 'setTheme',
            theme = theme
        })
    end
end

function UpdateAllPassiveScreens()
    UpdateThemeOnAllScreens()
end

function SendDuiMessageToActiveSession(msgData)
    if currentActiveSession and currentActiveSession.screen and type(currentActiveSession.screen.send) == 'function' then
        currentActiveSession.screen:send(msgData)
    end
end

local function destroyPassiveScreen(benchId)
    local screenId = getPassiveScreenId(benchId)
    local api = getDuiApi()
    if api then
        local existing = api.get(screenId)
        if existing then
            existing:destroy()
        end
    end
    passiveScreens[benchId] = nil
end

-- Thread de gerenciamento de DUIs passivas nas bancadas próximas
CreateThread(function()
    while true do
        local sleep = 2000
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)

        -- Não renderizar passivo se há sessão interativa ativa
        if not currentActiveSession and workshops and #workshops > 0 then
            local nearbyIds = {}

            for _, bench in ipairs(workshops) do
                local bCoords = vector3(bench.coords.x, bench.coords.y, bench.coords.z)
                local dist = #(pCoords - bCoords)

                if dist <= 14.0 then
                    nearbyIds[bench.id] = true

                    if not passiveScreens[bench.id] then
                        local screen = createPassiveScreen(bench)
                        if screen then
                            passiveScreens[bench.id] = screen
                            sleep = 500
                        end
                    end
                end
            end

            -- Destruir screens de bancadas que ficaram distantes
            for benchId, _ in pairs(passiveScreens) do
                if not nearbyIds[benchId] then
                    destroyPassiveScreen(benchId)
                end
            end
        else
            -- Se há sessão ativa, destruir todos os passivos
            for benchId, _ in pairs(passiveScreens) do
                destroyPassiveScreen(benchId)
            end
        end

        Wait(sleep)
    end
end)

-- =====================================================
--  Sessão Interativa - Câmera, Ped, Mouse e DUI
-- =====================================================

function StartBenchDuiSession(bench, formattedItems, playerLevel)
    if currentActiveSession then
        StopBenchDuiSession()
        Wait(50)
    end

    -- Destruir imediatamente todas as telas passivas para evitar sobreposição na bancada
    for bId, _ in pairs(passiveScreens) do
        destroyPassiveScreen(bId)
    end
    passiveScreens = {}

    local ped = PlayerPedId()
    local bModel = bench.bench_model or {}

    -- Encontrar prop da bancada no mundo se não foi anexado
    local entity = bench.entity
    if (not entity or not DoesEntityExist(entity)) and bench.coords then
        local propCoords = vector3(bench.coords.x, bench.coords.y, bench.coords.z)
        local modelHash = type(bench.model) == 'string' and joaat(bench.model) or bench.model
        if modelHash then
            local closest = GetClosestObjectOfType(propCoords.x, propCoords.y, propCoords.z, 2.5, modelHash, false, false, false)
            if DoesEntityExist(closest) then
                entity = closest
                bench.entity = closest
            end
        end
    end

    -- Priorizar coordenadas e heading do prop físico no mundo se existir
    local heading = (entity and DoesEntityExist(entity) and GetEntityHeading(entity))
        or bench.heading
        or (bench.coords and (bench.coords.w or bench.coords.heading))
        or 0.0
    heading = tonumber(heading) or 0.0

    -- Usar sempre vector3 base para manter harmonia matemática com a calibração
    local benchBaseCoords = (entity and DoesEntityExist(entity) and GetEntityCoords(entity))
        or (bench.coords and vector3(bench.coords.x, bench.coords.y, bench.coords.z))
        or GetEntityCoords(ped)

    local headingRad = degToRad(heading)
    local forward = vector3(-math.sin(headingRad), math.cos(headingRad), 0.0)

    -- 1. Calcular pontos do polígono DUI
    local p1, p2, p3, p4 = calculateBenchPolyPoints(benchBaseCoords, heading, bModel)
    local centerCoords = (p1 + p2 + p3 + p4) * 0.25

    -- 2. Posicionar Ped (jogador) com animação IMEDIATAMENTE (nunca esperar DUI)
    local animOffset = bModel.anim_offset or {}
    local playerPedCoords
    local playerHeading

    if animOffset.x and animOffset.y and animOffset.z then
        playerPedCoords = getRelativeOffset(benchBaseCoords, heading, animOffset)
        playerHeading = (heading + (tonumber(animOffset.heading) or 0.0)) % 360.0
    else
        local pedDist = tonumber(animOffset.distance or animOffset.forward or animOffset.y or animOffset.x) or 1.05
        local pedLateral = tonumber(animOffset.lateral or animOffset.x) or 0.0
        local pedHeadingOffset = tonumber(animOffset.heading or animOffset.rotation or animOffset.w) or 0.0
        local right = vector3(math.cos(headingRad), math.sin(headingRad), 0.0)

        playerPedCoords = centerCoords - forward * pedDist + right * pedLateral
        local foundGround, groundZ = GetGroundZFor_3dCoord(playerPedCoords.x, playerPedCoords.y, benchBaseCoords.z + 1.0, false)
        local pedZ = foundGround and (groundZ + 0.98) or benchBaseCoords.z
        playerPedCoords = vector3(playerPedCoords.x, playerPedCoords.y, pedZ)
        playerHeading = (heading + pedHeadingOffset) % 360.0
    end

    SetEntityCoordsNoOffset(ped, playerPedCoords.x, playerPedCoords.y, playerPedCoords.z, false, false, false)
    SetEntityHeading(ped, playerHeading)
    FreezeEntityPosition(ped, true)

    local animDict = bModel.anim_dict or 'anim@amb@board_room@diagram_blueprints@'
    local animName = bModel.anim_name or 'idle_01_amy_skater_01'
    local streaming = pr_lib and pr_lib.fivem and pr_lib.fivem.streaming
    if streaming and streaming.requestAnimDict then
        streaming.requestAnimDict(animDict, 3000)
    else
        RequestAnimDict(animDict)
        local timeout = GetGameTimer() + 2000
        while not HasAnimDictLoaded(animDict) and GetGameTimer() < timeout do Wait(10) end
    end
    if HasAnimDictLoaded(animDict) then
        TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    -- 3. Posicionar e Ativar Câmera IMEDIATAMENTE
    local camOffset = bModel.cam_offset or {}
    local function safeCameraNumber(value, fallback, minValue, maxValue)
        local number = tonumber(value)
        if not number or number ~= number or number == math.huge or number == -math.huge then
            return fallback
        end
        if minValue then number = math.max(minValue, number) end
        if maxValue then number = math.min(maxValue, number) end
        return number
    end

    local camX = safeCameraNumber(camOffset.x)
    local camY = safeCameraNumber(camOffset.y)
    local camZ = safeCameraNumber(camOffset.z)
    local hasSafeCamOffset = camX and camY and camZ
        and math.abs(camX) <= 25.0
        and math.abs(camY) <= 25.0
        and math.abs(camZ) <= 25.0
    local camFov = safeCameraNumber(camOffset.fov, 50.0, 15.0, 115.0)
    local cameraCoords

    if hasSafeCamOffset then
        cameraCoords = getRelativeOffset(benchBaseCoords, heading, { x = camX, y = camY, z = camZ })
    else
        local camDistance = safeCameraNumber(camOffset.distance, 0.90, -25.0, 25.0)
        local camHeightAbove = safeCameraNumber(camOffset.height, 0.42, -5.0, 25.0)
        local camLateral = safeCameraNumber(camOffset.lateral, 0.0, -25.0, 25.0)
        local right = vector3(math.cos(headingRad), math.sin(headingRad), 0.0)
        cameraCoords = centerCoords - forward * camDistance + right * camLateral + vector3(0.0, 0.0, camHeightAbove)
    end

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    if hasSafeCamOffset and camOffset.rotX and camOffset.rotZ then
        local camWorldRotZ = (heading + safeCameraNumber(camOffset.rotZ, 0.0)) % 360.0
        SetCamRot(cam, safeCameraNumber(camOffset.rotX, 0.0, -89.9, 25.0), safeCameraNumber(camOffset.rotY, 0.0), camWorldRotZ, 2)
    else
        PointCamAtCoord(cam, centerCoords.x, centerCoords.y, centerCoords.z)
    end
    SetCamFov(cam, camFov)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 450, 1, 0)

    -- 4. Criar ou Obter DUI via pr_bridge
    local api = getDuiApi()
    local screenId = 'forge_crafting_session_' .. tostring(bench.id)
    if api and api.destroy then
        api.destroy(screenId)
    end

    local screen = nil
    if api and api.createPoly then
        screen = api.createPoly({
            id = screenId,
            url = getDuiUrl(),
            width = DUI_WIDTH,
            height = DUI_HEIGHT,
            p1 = p1,
            p2 = p2,
            p3 = p3,
            p4 = p4,
            renderDistance = 35.0,
            color = { 255, 255, 255, 255 },
            mouse = false,
        })
    end

    if not screen then
        print("[forge-crafting] AVISO: Nao foi possivel criar a tela DUI para a bancada " .. tostring(bench.id))
    end

    -- 5. Enviar dados para a DUI
    CreateThread(function()
        for i = 1, 6 do
            Wait(i == 1 and 200 or 250)
            if currentActiveSession and currentActiveSession.screen and type(currentActiveSession.screen.send) == 'function' then
                currentActiveSession.screen:send({
                    action = 'open',
                    bench = {
                        id = bench.id,
                        name = bench.name,
                        coords = bench.coords,
                        model = bench.model,
                        model_slug = bench.model_slug
                    },
                    items = formattedItems or {},
                    playerLevel = playerLevel or 0,
                    imagePath = 'images/',
                    theme = (GetCurrentTheme and GetCurrentTheme()) or {},
                })
            end
        end
    end)

    -- Ativar foco NUI apenas para o cursor do mouse (sem capturar teclado)
    SetNuiFocus(true, false)
    SetCursorLocation(0.5, 0.5)

    currentActiveSession = {
        bench = bench,
        benchBaseCoords = benchBaseCoords,
        camera = cam,
        screen = screen,
        centerCoords = centerCoords,
        heading = heading,
        ped = ped,
        p1 = p1,
        p2 = p2,
        p3 = p3,
        p4 = p4,
    }

    -- 6. Loop de Sessão (Mapeamento de Câmera 3D via Raycast, Cursor e Eventos Mouse/Teclado)
    CreateThread(function()
        local thisSession = currentActiveSession
        local lastPx, lastPy = -1, -1

        while currentActiveSession and currentActiveSession == thisSession do
            Wait(0)

            -- Manter cursor do mouse visível e ativo na tela
            SetMouseCursorActiveThisFrame()

            -- Desabilitar controles que interferem na navegação do mouse e câmera do jogo
            DisableControlAction(0, 1, true)   -- Look Left/Right
            DisableControlAction(0, 2, true)   -- Look Up/Down
            DisableControlAction(0, 24, true)  -- Attack / LMB
            DisableControlAction(0, 25, true)  -- Aim / RMB
            DisableControlAction(0, 14, true)  -- Weapon Wheel Next / Scroll Down
            DisableControlAction(0, 15, true)  -- Weapon Wheel Prev / Scroll Up
            DisableControlAction(0, 180, true) -- Weapon Wheel Next (alt)
            DisableControlAction(0, 181, true) -- Weapon Wheel Prev (alt)
            DisableControlAction(0, 237, true) -- Cursor Accept
            DisableControlAction(0, 238, true) -- Cursor Cancel
            DisableControlAction(0, 239, true) -- Cursor X
            DisableControlAction(0, 240, true) -- Cursor Y
            DisableControlAction(0, 200, true) -- ESC
            DisableControlAction(0, 177, true) -- BACKSPACE
            DisableControlAction(0, 30, true)  -- Move LR
            DisableControlAction(0, 31, true)  -- Move UD
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Jump

            -- Tecla ESC / BACKSPACE para encerrar a sessão
            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 177) or IsControlJustReleased(0, 200) or IsControlJustReleased(0, 177) then
                StopBenchDuiSession()
                break
            end

            local activeScreen = thisSession.screen
            local duiObj = activeScreen and (activeScreen.duiObject or activeScreen.dui)

            if duiObj and (type(IsDuiAvailable) ~= "function" or IsDuiAvailable(duiObj)) then
                -- Raycast preciso da Câmera Scriptada sobre o plano 3D da bancada
                local camCoords, rayDir = getCameraRay(thisSession.camera or cam)
                local relX, relY = mapRayToDui(camCoords, rayDir, p1, p2, p3, p4)

                local px = math.floor(relX * (DUI_WIDTH - 1))
                local py = math.floor(relY * (DUI_HEIGHT - 1))

                if px ~= lastPx or py ~= lastPy then
                    lastPx = px
                    lastPy = py
                    pcall(SendDuiMouseMove, duiObj, px, py)
                end

                -- Clique Esquerdo (LMB ou Cursor Accept)
                if IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 237) or IsControlJustPressed(0, 24) or IsControlJustPressed(0, 237) then
                    pcall(SendDuiMouseMove, duiObj, px, py)
                    pcall(SendDuiMouseDown, duiObj, "left")
                end
                if IsDisabledControlJustReleased(0, 24) or IsDisabledControlJustReleased(0, 237) or IsControlJustReleased(0, 24) or IsControlJustReleased(0, 237) then
                    pcall(SendDuiMouseUp, duiObj, "left")
                end

                -- Clique Direito (RMB ou Cursor Cancel)
                if IsDisabledControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 238) or IsControlJustPressed(0, 25) or IsControlJustPressed(0, 238) then
                    pcall(SendDuiMouseMove, duiObj, px, py)
                    pcall(SendDuiMouseDown, duiObj, "right")
                end
                if IsDisabledControlJustReleased(0, 25) or IsDisabledControlJustReleased(0, 238) or IsControlJustReleased(0, 25) or IsControlJustReleased(0, 238) then
                    pcall(SendDuiMouseUp, duiObj, "right")
                end

                -- Scroll do Mouse (Wheel)
                if IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 180) then
                    pcall(SendDuiMouseWheel, duiObj, 0, -120)
                end
                if IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 181) then
                    pcall(SendDuiMouseWheel, duiObj, 0, 120)
                end
            end
        end
    end)
end

-- =====================================================
--  Gerenciamento de Arma 3D Física na Bancada (Upgrades)
-- =====================================================

local currentActiveUpgradeWeapon = {
    entity = nil,
    weaponHash = nil,
    weaponData = nil,
    installedComponents = {},
    explodedObjects = {},
    exploded = false,
}

local function applyUpgradeWeaponBaseTransform(state)
    if not state or not state.entity or not DoesEntityExist(state.entity) then return false end

    if state.baseCoords then
        SetEntityCoordsNoOffset(
            state.entity,
            state.baseCoords.x,
            state.baseCoords.y,
            state.baseCoords.z,
            false,
            false,
            false
        )
    end
    if state.baseRotation then
        SetEntityRotation(
            state.entity,
            state.baseRotation.x,
            state.baseRotation.y,
            state.baseRotation.z,
            2,
            true
        )
    end

    SetEntityCollision(state.entity, false, false)
    FreezeEntityPosition(state.entity, true)
    return true
end

local function getUpgradeWeaponComponentItems(weaponData)
    if type(weaponData) ~= 'table' then return {} end

    local components = weaponData.components or (weaponData.metadata and weaponData.metadata.components) or {}
    if type(components) == 'string' and components ~= '' then return { components } end
    if type(components) ~= 'table' then return {} end

    local result = {}
    for _, componentItem in pairs(components) do
        if componentItem ~= nil and tostring(componentItem) ~= '' then
            result[#result + 1] = tostring(componentItem)
        end
    end
    return result
end

local function syncUpgradeWeaponVisuals(state)
    if not state or not state.entity or not DoesEntityExist(state.entity) then return false end

    -- Remover somente os componentes que esta visualizacao controlava. Os
    -- componentes padrao criados pelo proprio modelo da arma permanecem.
    for _, component in ipairs(state.installedComponents or {}) do
        if component.hash then
            RemoveWeaponComponentFromWeaponObject(state.entity, component.hash)
        end
    end

    local installedComponents = {}
    for _, componentItem in ipairs(getUpgradeWeaponComponentItems(state.weaponData)) do
        local componentHash = WeaponComponentsConfig.ResolveComponentHash(state.weaponData.name, componentItem)
        if componentHash and DoesWeaponTakeWeaponComponent(state.weaponHash, componentHash) then
            GiveWeaponComponentToWeaponObject(state.entity, componentHash)
            installedComponents[#installedComponents + 1] = {
                item = componentItem,
                hash = componentHash,
                slot = WeaponComponentsConfig.GetSlot(componentItem),
            }
        end
    end
    state.installedComponents = installedComponents

    -- Tints simples e kits at_skin_* sao caminhos diferentes: o primeiro usa
    -- o indice nativo, enquanto os kits acima sao componentes CAMO/VARMOD.
    local tintIndex = tonumber(state.weaponData.tint or (state.weaponData.metadata and state.weaponData.metadata.tint)) or 0
    SetWeaponObjectTintIndex(state.entity, tintIndex)

    -- Componentes podem alterar o bounding box visual, mas nunca devem alterar
    -- a ancora calibrada da arma sobre a bancada.
    applyUpgradeWeaponBaseTransform(state)
    return true
end

function ClearUpgradeWeaponObject()
    if currentActiveUpgradeWeapon and type(currentActiveUpgradeWeapon.explodedObjects) == 'table' then
        for _, componentObject in ipairs(currentActiveUpgradeWeapon.explodedObjects) do
            if componentObject and DoesEntityExist(componentObject) then
                DeleteEntity(componentObject)
            end
        end
    end
    if currentActiveUpgradeWeapon and currentActiveUpgradeWeapon.entity and DoesEntityExist(currentActiveUpgradeWeapon.entity) then
        DeleteEntity(currentActiveUpgradeWeapon.entity)
    end
    currentActiveUpgradeWeapon = {
        entity = nil,
        weaponHash = nil,
        weaponData = nil,
        installedComponents = {},
        explodedObjects = {},
        exploded = false,
    }
end

function SpawnUpgradeWeaponObject(weaponData)
    ClearUpgradeWeaponObject()

    if not currentActiveSession or not weaponData or not weaponData.name then
        return nil
    end

    local p1 = currentActiveSession.p1
    local p2 = currentActiveSession.p2
    local p3 = currentActiveSession.p3
    local p4 = currentActiveSession.p4

    if not p1 or not p2 or not p3 or not p4 then
        return nil
    end

    -- Normal do plano da bancada
    local horizontal = p2 - p1
    local vertical = p4 - p1
    local normal = vector3(
        horizontal.y * vertical.z - horizontal.z * vertical.y,
        horizontal.z * vertical.x - horizontal.x * vertical.z,
        horizontal.x * vertical.y - horizontal.y * vertical.x
    )
    if normal.z < 0.0 then normal = -normal end
    local len = #(normal)
    if len > 0.001 then
        normal = normal / len
    else
        normal = vector3(0.0, 0.0, 1.0)
    end

    -- Verificar se o perfil da bancada possui weapon_offset calibrado
    local bModel = (currentActiveSession.bench and currentActiveSession.bench.bench_model) or {}
    local benchEntity = currentActiveSession.bench and currentActiveSession.bench.entity
    local benchBaseCoords = currentActiveSession.benchBaseCoords
    local benchHeading = tonumber(currentActiveSession.heading) or 0.0

    if benchEntity and DoesEntityExist(benchEntity) then
        benchHeading = GetEntityHeading(benchEntity)
    end

    local weaponPos
    if bModel.weapon_offset then
        if benchBaseCoords then
            weaponPos = getRelativeOffset(benchBaseCoords, benchHeading, bModel.weapon_offset)
        end
    end

    if not weaponPos then
        -- Posição paramétrica na mesa (u = 0.67 largura, v = 0.72 altura - abaixo dos 6 slots de componentes)
        local u = 0.67
        local v = 0.72
        local basePos = (1.0 - u) * (1.0 - v) * p1 +
                        u * (1.0 - v) * p2 +
                        u * v * p3 +
                        (1.0 - u) * v * p4
        -- Leve elevação na normal para apoiar perfeitamente sobre a mesa sem z-fight
        weaponPos = basePos + (normal * 0.032)
    end

    local weaponName = tostring(weaponData.name)
    local weaponHash = joaat(string.upper(weaponName))

    RequestWeaponAsset(weaponHash, 31, 0)
    local timeout = GetGameTimer() + 2500
    while not HasWeaponAssetLoaded(weaponHash) and GetGameTimer() < timeout do
        Wait(10)
    end

    local weaponObj = CreateWeaponObject(weaponHash, 1, weaponPos.x, weaponPos.y, weaponPos.z, true, 1.0, 0)
    if not weaponObj or not DoesEntityExist(weaponObj) then
        print(('[forge-crafting] Falha ao criar WeaponObject para %s'):format(weaponName))
        return nil
    end

    -- Rotação: Usar offset calibrado ou fallback horizontal deitado de lado na bancada
    local rotationX, rotationY, rotationZ
    if bModel.weapon_offset and (bModel.weapon_offset.rotX or bModel.weapon_offset.rotY or bModel.weapon_offset.rotZ) then
        rotationX = tonumber(bModel.weapon_offset.rotX) or 0.0
        rotationY = tonumber(bModel.weapon_offset.rotY) or 0.0
        rotationZ = ((tonumber(bModel.weapon_offset.rotZ) or 0.0) + benchHeading) % 360.0
    else
        -- Mesmo fallback usado pelo calibrador. Antes o editor usava 0/0/+90
        -- e o runtime 0/90/-90, fazendo a arma aparecer em pé na bancada.
        rotationX = 0.0
        rotationY = 0.0
        rotationZ = (benchHeading + 90.0) % 360.0
    end

    currentActiveUpgradeWeapon = {
        entity = weaponObj,
        weaponHash = weaponHash,
        weaponData = weaponData,
        installedComponents = {},
        explodedObjects = {},
        exploded = false,
        -- Guardar a transformacao calculada, nao uma leitura posterior do prop.
        -- Assim toda atualizacao volta exatamente para a mesma ancora calibrada.
        baseCoords = vector3(weaponPos.x, weaponPos.y, weaponPos.z),
        baseRotation = vector3(rotationX, rotationY, rotationZ),
        planeNormal = normal,
    }

    syncUpgradeWeaponVisuals(currentActiveUpgradeWeapon)

    return weaponObj
end

local explodedOffsets = {
    -- Deslocamentos de aproximadamente 2 cm: equivalentes a cerca de 10
    -- pixels na camera atual da bancada, sempre a partir do encaixe original.
    suppressor = { x = 0.000, y = 0.024, z = -0.006 },
    scope = { x = 0.000, y = 0.000, z = 0.020 },
    flashlight = { x = 0.012, y = 0.008, z = -0.016 },
    magazine = { x = 0.000, y = -0.006, z = -0.024 },
    grip = { x = -0.012, y = -0.008, z = -0.020 },
}

-- Bones de encaixe usados pelos modelos de arma do GTA. A posicao do bone e
-- convertida para o espaco local da arma antes de qualquer componente ser
-- removido. Desse modo a vista explodida parte do encaixe verdadeiro, e nao da
-- origem/centro do WeaponObject.
local componentBoneCandidates = {
    suppressor = { 'WAPSupp', 'WAPSupp_2', 'WAPMuzzle', 'WAPBarrel' },
    scope = { 'WAPScop', 'WAPScop_2', 'WAPSights' },
    flashlight = { 'WAPFlsh', 'WAPFlshLasr', 'WAPLasr' },
    magazine = { 'WAPClip', 'WAPClip_2', 'WAPMag' },
    grip = { 'WAPGrip', 'WAPGrip_2' },
}

-- Fallback apenas para armas customizadas que nao exponham os bones padrao.
-- Mesmo nesse caso cada tipo permanece na sua regiao da arma, nunca no centro.
local componentFallbackAnchors = {
    suppressor = { x = 0.000, y = 0.320, z = 0.000 },
    scope = { x = 0.000, y = 0.040, z = 0.065 },
    flashlight = { x = 0.040, y = 0.100, z = -0.025 },
    magazine = { x = 0.000, y = -0.045, z = -0.090 },
    grip = { x = -0.025, y = -0.020, z = -0.070 },
}

local function getWeaponComponentAnchorOffset(state, slot)
    local boneCandidates = componentBoneCandidates[slot] or {}
    for _, boneName in ipairs(boneCandidates) do
        local boneIndex = GetEntityBoneIndexByName(state.entity, boneName)
        if boneIndex and boneIndex ~= -1 then
            local worldCoords = GetWorldPositionOfEntityBone(state.entity, boneIndex)
            if worldCoords then
                local localCoords = GetOffsetFromEntityGivenWorldCoords(
                    state.entity,
                    worldCoords.x,
                    worldCoords.y,
                    worldCoords.z
                )
                if localCoords
                    and math.abs(localCoords.x) < 5.0
                    and math.abs(localCoords.y) < 5.0
                    and math.abs(localCoords.z) < 5.0 then
                    return localCoords
                end
            end
        end
    end

    local fallback = componentFallbackAnchors[slot] or { x = 0.0, y = 0.0, z = 0.0 }
    return vector3(fallback.x, fallback.y, fallback.z)
end

local function clearExplodedObjects()
    for _, componentObject in ipairs(currentActiveUpgradeWeapon.explodedObjects or {}) do
        if componentObject and DoesEntityExist(componentObject) then
            DeleteEntity(componentObject)
        end
    end
    currentActiveUpgradeWeapon.explodedObjects = {}
end

function SetUpgradeWeaponExplodedView(enabled)
    local state = currentActiveUpgradeWeapon
    if not state or not state.entity or not DoesEntityExist(state.entity) then return false end

    enabled = enabled == true
    if state.exploded == enabled then return true end

    clearExplodedObjects()

    if not enabled then
        for _, component in ipairs(state.installedComponents or {}) do
            GiveWeaponComponentToWeaponObject(state.entity, component.hash)
        end
        applyUpgradeWeaponBaseTransform(state)
        state.exploded = false
        return true
    end

    -- Sempre partir da ancora canonica impede que alternancias acumulem
    -- deslocamento na profundidade/altura.
    applyUpgradeWeaponBaseTransform(state)

    -- Capturar a posicao original de cada encaixe enquanto todos os
    -- componentes ainda estao instalados na arma.
    local componentAnchorOffsets = {}
    for index, component in ipairs(state.installedComponents or {}) do
        if explodedOffsets[component.slot] then
            componentAnchorOffsets[index] = getWeaponComponentAnchorOffset(state, component.slot)
        end
    end

    local planeNormal = state.planeNormal or vector3(0.0, 0.0, 1.0)
    local liftedCoords = state.baseCoords + (planeNormal * 0.008)
    SetEntityCoordsNoOffset(state.entity, liftedCoords.x, liftedCoords.y, liftedCoords.z, false, false, false)

    for index, component in ipairs(state.installedComponents or {}) do
        local offset = explodedOffsets[component.slot]
        -- Pinturas/camuflagens são superfícies da arma e permanecem aplicadas.
        if offset then
            local modelHash = GetWeaponComponentTypeModel(component.hash)
            if modelHash and modelHash ~= 0 and IsModelInCdimage(modelHash) then
                RequestModel(modelHash)
                local timeout = GetGameTimer() + 1500
                while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(0) end

                if HasModelLoaded(modelHash) then
                    local anchor = componentAnchorOffsets[index] or getWeaponComponentAnchorOffset(state, component.slot)
                    local componentCoords = GetOffsetFromEntityInWorldCoords(
                        state.entity,
                        anchor.x + offset.x,
                        anchor.y + offset.y,
                        anchor.z + offset.z
                    )
                    local componentObject = CreateObjectNoOffset(
                        modelHash,
                        componentCoords.x,
                        componentCoords.y,
                        componentCoords.z,
                        false,
                        false,
                        false
                    )
                    if componentObject and DoesEntityExist(componentObject) then
                        local weaponRotation = GetEntityRotation(state.entity, 2)
                        SetEntityRotation(componentObject, weaponRotation.x, weaponRotation.y, weaponRotation.z, 2, true)
                        SetEntityCollision(componentObject, false, false)
                        FreezeEntityPosition(componentObject, true)
                        RemoveWeaponComponentFromWeaponObject(state.entity, component.hash)
                        state.explodedObjects[#state.explodedObjects + 1] = componentObject
                    end
                    SetModelAsNoLongerNeeded(modelHash)
                end
            end
        end
    end

    state.exploded = true
    return true
end

function ToggleUpgradeWeaponExplodedView()
    local state = currentActiveUpgradeWeapon
    if not state or not state.entity or not DoesEntityExist(state.entity) then return false, false end
    local nextState = not state.exploded
    return SetUpgradeWeaponExplodedView(nextState), nextState
end

function AttachComponentToCurrentUpgradeWeapon(compHash)
    if not currentActiveUpgradeWeapon or not currentActiveUpgradeWeapon.entity or not DoesEntityExist(currentActiveUpgradeWeapon.entity) then
        return false
    end
    if not compHash then return false end

    local hashNum = type(compHash) == 'number' and compHash or joaat(tostring(compHash))
    if not DoesWeaponTakeWeaponComponent(currentActiveUpgradeWeapon.weaponHash, hashNum) then
        return false
    end
    GiveWeaponComponentToWeaponObject(currentActiveUpgradeWeapon.entity, hashNum)
    return true
end

function RemoveComponentFromCurrentUpgradeWeapon(compHash)
    if not currentActiveUpgradeWeapon or not currentActiveUpgradeWeapon.entity or not DoesEntityExist(currentActiveUpgradeWeapon.entity) then
        return false
    end
    if not compHash then return false end

    local hashNum = type(compHash) == 'number' and compHash or joaat(tostring(compHash))
    RemoveWeaponComponentFromWeaponObject(currentActiveUpgradeWeapon.entity, hashNum)
    return true
end

function SetCurrentUpgradeWeaponTint(tintIndex)
    if not currentActiveUpgradeWeapon or not currentActiveUpgradeWeapon.entity or not DoesEntityExist(currentActiveUpgradeWeapon.entity) then
        return false
    end
    if currentActiveUpgradeWeapon.exploded then
        SetUpgradeWeaponExplodedView(false)
    end
    local t = tonumber(tintIndex) or 0
    SetWeaponObjectTintIndex(currentActiveUpgradeWeapon.entity, t)
    if currentActiveUpgradeWeapon.weaponData then
        currentActiveUpgradeWeapon.weaponData.tint = t
        if currentActiveUpgradeWeapon.weaponData.metadata then
            currentActiveUpgradeWeapon.weaponData.metadata.tint = t
        end
    end
    applyUpgradeWeaponBaseTransform(currentActiveUpgradeWeapon)
    return true
end

function UpdateCurrentUpgradeWeaponComponents(metadataOrComponents)
    local state = currentActiveUpgradeWeapon
    if not state or not state.weaponData or not state.entity or not DoesEntityExist(state.entity) then return false end

    -- Uma instalacao pode ocorrer durante a vista expandida. Recolher primeiro
    -- evita objetos fantasmas e garante que a nova skin/peca apareca na hora.
    if state.exploded then
        SetUpgradeWeaponExplodedView(false)
    end

    if type(metadataOrComponents) == 'table' then
        if metadataOrComponents.components then
            state.weaponData.components = metadataOrComponents.components
            state.weaponData.metadata = metadataOrComponents
            if metadataOrComponents.tint ~= nil then
                state.weaponData.tint = metadataOrComponents.tint
            end
        else
            state.weaponData.components = metadataOrComponents
        end
    end

    return syncUpgradeWeaponVisuals(state)
end

function StopBenchDuiSession()
    if not currentActiveSession then return end

    ClearUpgradeWeaponObject()

    local session = currentActiveSession
    currentActiveSession = nil

    SetNuiFocus(false, false)

    -- Destruir screen DUI do pr_bridge
    if session.screen then
        pcall(function()
            session.screen:send({ action = 'close' })
        end)
        Wait(100)
        pcall(function()
            session.screen:destroy()
        end)
    end

    -- Restaurar câmera
    if session.camera and DoesCamExist(session.camera) then
        RenderScriptCams(false, true, 350, 1, 0)
        DestroyCam(session.camera, false)
    end

    -- Restaurar ped
    if session.ped and DoesEntityExist(session.ped) then
        FreezeEntityPosition(session.ped, false)
        ClearPedTasks(session.ped)
    end
end

function IsBenchDuiActive()
    return currentActiveSession ~= nil
end

function SendActiveDuiMessage(data)
    if currentActiveSession and currentActiveSession.screen and type(currentActiveSession.screen.send) == 'function' then
        currentActiveSession.screen:send(data)
        return true
    end
    return false
end

-- =====================================================
--  Função auxiliar para renderização DUI durante calibração
--  Usada pelo cl_benchtool.lua para mostrar DUI ao vivo
-- =====================================================

function CreateCalibrationDuiScreen(p1, p2, p3, p4, screenId)
    local api = getDuiApi()
    if not api then return nil end

    screenId = screenId or 'forge_crafting_calibration'

    local screen, err = api.createPoly({
        id = screenId,
        url = getDuiUrl(),
        width = DUI_WIDTH,
        height = DUI_HEIGHT,
        p1 = p1,
        p2 = p2,
        p3 = p3,
        p4 = p4,
        renderDistance = 35.0,
        color = { 255, 255, 255, 255 },
    })

    if screen then
        CreateThread(function()
            Wait(500)
            if screen and type(screen.send) == 'function' then
                screen:send({
                    action = 'open',
                    bench = { id = 0, name = 'Calibração' },
                    items = {{ item = 'item_teste', item_label = 'Item de Calibração', time = 5, amount = 1, level = 0, recipe = {} }},
                    playerLevel = 10,
                    imagePath = Config and Config.ImagePath or 'nui://ox_inventory/web/images/',
                })
            end
        end)
    end

    return screen
end

function DestroyCalibrationDuiScreen(screen)
    if screen then
        pcall(function() screen:send({ action = 'close' }) end)
        Wait(50)
        pcall(function() screen:destroy() end)
    end
end

function CreateUpgradeCalibrationDuiScreen(p1, p2, p3, p4, screenId)
    local api = getDuiApi()
    if not api then return nil end

    screenId = screenId or 'forge_crafting_calib_upgrade'

    local screen, err = api.createPoly({
        id = screenId,
        url = getDuiUrl(),
        width = DUI_WIDTH,
        height = DUI_HEIGHT,
        p1 = p1,
        p2 = p2,
        p3 = p3,
        p4 = p4,
        renderDistance = 35.0,
        color = { 255, 255, 255, 255 },
        mouse = false,
    })

    if screen then
        CreateThread(function()
            Wait(400)
            if screen and type(screen.send) == 'function' then
                local currentTheme = (GetCurrentTheme and GetCurrentTheme()) or {}
                screen:send({
                    action = 'open',
                    bench = { id = 0, name = 'Calibração de Arma' },
                    items = {},
                    playerLevel = 10,
                    imagePath = 'images/',
                    theme = currentTheme,
                })
                Wait(300)
                screen:send({
                    action = 'openUpgradeTab',
                    weapons = {
                        {
                            name = 'WEAPON_CARBINERIFLE_MK2',
                            label = 'Carabina Especial MK2',
                            count = 1,
                            slot = 1,
                            serial = 'CALIB-01',
                            ammo = 30,
                            durability = 100,
                            components = {}
                        }
                    },
                    attachments = {}
                })
            end
        end)
    end

    return screen
end


-- =====================================================
--  Limpeza ao parar o recurso
-- =====================================================

AddEventHandler('onResourceStop', function(res)
    if GetCurrentResourceName() ~= res then return end

    StopBenchDuiSession()

    -- Destruir todas as DUIs passivas
    for benchId, _ in pairs(passiveScreens) do
        destroyPassiveScreen(benchId)
    end
end)
