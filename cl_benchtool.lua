-- =====================================================
--  Forge Crafting - Ferramenta de Criação & Calibração de Bancada com DUI 3D
--  Baseado na lógica de outdoors do Forge-Core (client/billboards/main.lua)
--  e adaptado com coordenadas relativas ao prop e ajuste fino de altura.
-- =====================================================

local cameraTunerPlayerState = nil

local function restoreCameraTunerPlayer()
    local state = cameraTunerPlayerState
    cameraTunerPlayerState = nil
    if state and state.ped and DoesEntityExist(state.ped) then
        SetEntityVisible(state.ped, state.wasVisible, false)
    end
end

local function notify(title, message, msgType)
    if pr_lib.notifications and pr_lib.notifications.Notify then
        pr_lib.notifications.Notify({
            title = title or locales.main_title or "Bancada",
            description = message,
            type = msgType or "inform"
        })
    end
end

local function setText(text)
    if pr_lib and pr_lib.ShowTextUI then
        pr_lib.ShowTextUI(text, { position = 'right-center' })
    else
        BeginTextCommandDisplayHelp("STRING")
        AddTextComponentSubstringPlayerName(text)
        EndTextCommandDisplayHelp(0, false, false, -1)
    end
end

local function hideText()
    if pr_lib and pr_lib.HideTextUI then
        pr_lib.HideTextUI()
    end
end

local function degToRad(degrees)
    degrees = tonumber(degrees) or 0.0
    return degrees * math.pi / 180.0
end

local function vec3(value)
    if type(value) == 'vector3' then return value end
    value = type(value) == 'table' and value or {}
    return vector3(tonumber(value.x or value[1]) or 0.0, tonumber(value.y or value[2]) or 0.0, tonumber(value.z or value[3]) or 0.0)
end

local function serialVector(value)
    value = vec3(value)
    return {
        x = tonumber(('%0.3f'):format(value.x)),
        y = tonumber(('%0.3f'):format(value.y)),
        z = tonumber(('%0.3f'):format(value.z)),
    }
end

local function getRelativeOffset(baseCoordsOrEntity, headingDeg, offset)
    if type(baseCoordsOrEntity) == "number" and DoesEntityExist(baseCoordsOrEntity) then
        headingDeg = GetEntityHeading(baseCoordsOrEntity)
        baseCoordsOrEntity = GetEntityCoords(baseCoordsOrEntity)
    end

    local baseCoords = baseCoordsOrEntity or vector3(0.0, 0.0, 0.0)
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
    if type(baseCoordsOrEntity) == "number" and DoesEntityExist(baseCoordsOrEntity) then
        headingDeg = GetEntityHeading(baseCoordsOrEntity)
        baseCoordsOrEntity = GetEntityCoords(baseCoordsOrEntity)
    end

    local baseCoords = baseCoordsOrEntity or vector3(0.0, 0.0, 0.0)
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

local function normalFromVertices(topLeft, topRight, bottomLeft)
    local horizontal = topRight - topLeft
    local vertical = bottomLeft - topLeft
    local normal = vector3(
        horizontal.y * vertical.z - horizontal.z * vertical.y,
        horizontal.z * vertical.x - horizontal.x * vertical.z,
        horizontal.x * vertical.y - horizontal.y * vertical.x
    )

    if normal.z < 0 then
        normal = -normal
    end

    local length = #(normal)
    if length <= 0.001 then return vector3(0.0, 0.0, 1.0) end

    return normal / length
end

local function offsetVertices(vertices, offset)
    local topLeft = vec3(vertices[1])
    local topRight = vec3(vertices[2])
    local bottomLeft = vec3(vertices[3])
    local bottomRight = vec3(vertices[4])
    local normal = normalFromVertices(topLeft, topRight, bottomLeft) * (tonumber(offset) or 0.035)

    return topLeft + normal, topRight + normal, bottomLeft + normal, bottomRight + normal
end

-- Captura de ponto por Raycast com laser e esfera visual (Idêntico ao Forge-Core Billboards)
local function raycastPoint(label, previous)
    local captured = nil
    local cancelled = false
    setText(string.format("%s\n[E] Marcar Ponto  |  [BACKSPACE] Cancelar", label))

    while not captured and not cancelled do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 38, true) -- E
        DisableControlAction(0, 177, true) -- BACKSPACE
        DisableControlAction(0, 202, true) -- ESC
        DisablePlayerFiring(PlayerId(), true)

        local hit, coords
        if pr_lib and pr_lib.raycast and pr_lib.raycast.FromCamera then
            hit, _, coords = pr_lib.raycast.FromCamera(100.0, 1, 4)
        else
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            local radZ = degToRad(camRot.z)
            local radX = degToRad(camRot.x)
            local forward = vector3(-math.sin(radZ) * math.cos(radX), math.cos(radZ) * math.cos(radX), math.sin(radX))
            local dest = camCoords + forward * 50.0
            local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, dest.x, dest.y, dest.z, -1, PlayerPedId(), 0)
            local res, hitRes, endCoords = GetShapeTestResult(ray)
            hit = hitRes == 1 or hitRes == true
            coords = endCoords
        end

        if hit and coords then
            local point = vec3(coords)
            DrawSphere(point.x, point.y, point.z, 0.04, 0, 220, 255, 0.75)

            if previous then
                for _, prevPoint in ipairs(previous) do
                    prevPoint = vec3(prevPoint)
                    DrawSphere(prevPoint.x, prevPoint.y, prevPoint.z, 0.04, 0, 255, 120, 0.65)
                    DrawLine(prevPoint.x, prevPoint.y, prevPoint.z, point.x, point.y, point.z, 0, 220, 255, 190)
                end
            end

            if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                captured = point
            end
        end

        if IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 177) or IsControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 202) then
            cancelled = true
        end
    end

    hideText()

    if cancelled then return nil, 'cancelled' end
    return captured
end

-- Captura dos 4 cantos da face da mesa
local function captureBenchVertices()
    local captured = {}
    local labels = {
        "1. Superior Esquerdo (Top-Left da DUI)",
        "2. Superior Direito (Top-Right da DUI)",
        "3. Inferior Direito (Bottom-Right da DUI)",
        "4. Inferior Esquerdo (Bottom-Left da DUI)",
    }

    for index, label in ipairs(labels) do
        local point, error = raycastPoint(label, captured)
        if not point then
            return false, error
        end

        captured[index] = point
        Wait(200)
    end

    return true, {
        captured[1],
        captured[2],
        captured[3],
        captured[4]
    }
end

-- Ferramenta de Ajuste Fino de Altura da DUI (Sobe e desce a DUI no prop em tempo real)
local function fineTuneBenchHeight(vertices, initialOffset)
    local currentOffset = tonumber(initialOffset) or 0.035
    local isTuning = true

    while isTuning do
        Wait(0)
        DisableControlAction(0, 172, true) -- Seta Cima
        DisableControlAction(0, 173, true) -- Seta Baixo
        DisableControlAction(0, 201, true) -- ENTER
        DisableControlAction(0, 177, true) -- BACKSPACE
        DisableControlAction(0, 202, true) -- ESC

        local step = 0.0015
        if IsControlPressed(0, 21) or IsDisabledControlPressed(0, 21) then
            step = 0.005 -- Shift para ajuste mais rápido
        end

        if IsControlPressed(0, 172) or IsDisabledControlPressed(0, 172) then
            currentOffset = math.min(1.0, currentOffset + step)
        elseif IsControlPressed(0, 173) or IsDisabledControlPressed(0, 173) then
            currentOffset = math.max(-0.5, currentOffset - step)
        end

        local p1, p2, p3, p4 = offsetVertices(vertices, currentOffset)

        -- Desenha as linhas guias do contorno em verde fluorescente
        DrawLine(p1.x, p1.y, p1.z, p2.x, p2.y, p2.z, 0, 255, 120, 230)
        DrawLine(p2.x, p2.y, p2.z, p4.x, p4.y, p4.z, 0, 255, 120, 230)
        DrawLine(p4.x, p4.y, p4.z, p3.x, p3.y, p3.z, 0, 255, 120, 230)
        DrawLine(p3.x, p3.y, p3.z, p1.x, p1.y, p1.z, 0, 255, 120, 230)

        -- Desenha a textura da DUI ao vivo
        -- A DUI de calibração é mostrada via pr_bridge (se disponível)
        -- Caso contrário, apenas as linhas guias são suficientes

        setText(string.format("Ajuste Fino de Altura da DUI\nOffset Atual: %+.3f m\n[↑] Subir  |  [↓] Descer  |  [SHIFT] Rápido\n[ENTER] Confirmar  |  [BACKSPACE] Cancelar", currentOffset))

        if IsControlJustPressed(0, 201) or IsDisabledControlJustPressed(0, 201) then
            isTuning = false
            hideText()
            return true, currentOffset
        elseif IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 177) or IsControlJustPressed(0, 202) or IsDisabledControlJustPressed(0, 202) then
            isTuning = false
            hideText()
            return false, 'cancelled'
        end
    end

    hideText()
    return false, 'cancelled'
end

-- Posicionamento com Gizmo 3D do prop da mesa
local function spawnAndPlaceProp(modelName, title, cb)
    local gizmoApi = (pr_lib.fivem and pr_lib.fivem.gizmo) or pr_lib.gizmo
    local streaming = pr_lib.fivem and pr_lib.fivem.streaming
    local modelHash = type(modelName) == "string" and joaat(modelName) or modelName

    local loaded = false
    if streaming and streaming.requestModel then
        loaded, modelHash = streaming.requestModel(modelHash, 3000)
    else
        RequestModel(modelHash)
        local timeout = GetGameTimer() + 3000
        while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(10) end
        loaded = HasModelLoaded(modelHash)
    end

    if not loaded then
        notify(locales.main_title, "Falha ao carregar modelo do prop: " .. tostring(modelName), "error")
        if cb then cb(nil, nil, false) end
        return
    end

    local ped = PlayerPedId()
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    local spawnHeading = GetEntityHeading(ped)

    local obj = CreateObjectNoOffset(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, true, false)
    if streaming and streaming.releaseModel then
        streaming.releaseModel(modelHash)
    else
        SetModelAsNoLongerNeeded(modelHash)
    end

    if not obj or obj == 0 or not DoesEntityExist(obj) then
        notify(locales.main_title, "Falha ao criar prop no mundo.", "error")
        if cb then cb(nil, nil, false) end
        return
    end

    SetEntityHeading(obj, spawnHeading)
    SetEntityAsMissionEntity(obj, true, true)
    FreezeEntityPosition(obj, true)

    if not gizmoApi or not gizmoApi.await then
        notify(locales.main_title, "Bancada criada na frente do personagem.", "inform")
        if cb then cb(obj, spawnCoords, spawnHeading, true) end
        return
    end

    local confirmedResult, finalResult = gizmoApi.await(obj, {
        title = title or "Posicionar Bancada (TAB: Modo Precisão)",
        offset = vector3(0.0, 0.0, 0.0),
        precisionMode = false,
        precisionSpeed = 1.0,
        allowFreeCameraToggle = true,
        restoreOnCancel = true,
        ui = true,
    })

    local result = confirmedResult or finalResult or { confirmed = false }
    local finalCoords = result.coords or GetEntityCoords(obj)
    local finalRotation = result.rotation or GetEntityRotation(obj, 2)
    local finalHeading = (type(finalRotation) == 'vector3' and finalRotation.z)
        or (type(finalRotation) == 'table' and (finalRotation.z or finalRotation[3]))
        or (DoesEntityExist(obj) and GetEntityHeading(obj))
        or 0.0
    finalHeading = tonumber(finalHeading) or 0.0

    if result.confirmed then
        notify(locales.main_title, "Posição da bancada confirmada.", "success")
        if cb then cb(obj, finalCoords, finalHeading, true) end
    else
        notify(locales.main_title, "Posicionamento cancelado.", "inform")
        if DoesEntityExist(obj) then DeleteObject(obj) end
        if cb then cb(nil, nil, nil, false) end
    end
end

-- =====================================================
--  Sintonizador de Câmera Focada na Bancada (Órbita e Altura)
-- =====================================================

local function startBenchCameraTuner(benchBaseCoords, benchHeading, centerCoords, defaultCamOffset, testPed, animDict, animName, finalPedCoords, finalPedHeading, onConfirm, onCancel)
    -- O Gizmo encerra a sessao antes de terminar a transicao de 500 ms da
    -- camera do PR Bridge. Se a camera deste tuner nascer durante essa janela,
    -- o cleanup atrasado do Gizmo chama RenderScriptCams(false) e a desativa.
    -- Libere explicitamente a camera publica do editor e espere a transicao
    -- terminar antes de assumir a propriedade da renderizacao.
    local editorCameraApi = pr_lib and pr_lib.fivem and pr_lib.fivem.editorCamera
    if editorCameraApi then
        if type(editorCameraApi.stop) == "function" then
            pcall(editorCameraApi.stop)
        end
        if type(editorCameraApi.stopFreecam) == "function" then
            pcall(editorCameraApi.stopFreecam)
        end
    end
    Wait(550)
    RenderScriptCams(false, false, 0, false, false)
    DestroyAllCams(true)
    Wait(50)

    -- O criador pode fornecer a entidade da bancada. Normalize uma única vez
    -- para o mesmo espaço local (X/Y/Z + heading) usado por DUI, ped e runtime.
    if type(benchBaseCoords) == "number" and DoesEntityExist(benchBaseCoords) then
        benchHeading = GetEntityHeading(benchBaseCoords)
        benchBaseCoords = GetEntityCoords(benchBaseCoords)
    end
    benchHeading = tonumber(benchHeading) or 0.0

    -- O ped real do administrador permanecia no mundo e a câmera de calibração
    -- podia nascer dentro do seu torso. O ped de teste continua visível para
    -- representar fielmente a posição configurada.
    local playerPed = PlayerPedId()
    local playerWasVisible = IsEntityVisible(playerPed)
    if playerPed ~= testPed then
        cameraTunerPlayerState = { ped = playerPed, wasVisible = playerWasVisible }
        SetEntityVisible(playerPed, false, false)
    end

    -- Fixar e manter o Ped de teste na posição configurada com o Gizmo
    if testPed and DoesEntityExist(testPed) then
        if finalPedCoords then
            SetEntityCoordsNoOffset(testPed, finalPedCoords.x, finalPedCoords.y, finalPedCoords.z, false, false, false)
        end
        if finalPedHeading then
            SetEntityHeading(testPed, finalPedHeading)
        end
        FreezeEntityPosition(testPed, true)
        SetEntityInvincible(testPed, true)
        SetBlockingOfNonTemporaryEvents(testPed, true)
        if animDict and animName then
            TaskPlayAnim(testPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
        end
    end

    local targetPos = vector3(centerCoords.x, centerCoords.y, centerCoords.z)
    local centerRel = reverseRelativeOffset(benchBaseCoords, benchHeading, targetPos)

    -- Posições relativas à bancada (Coordenadas locais X = lateral, Y = profundidade frente/trás, Z = altura)
    local camRelX = centerRel.x
    local camRelY = centerRel.y - 0.75
    local camRelZ = centerRel.z + 0.65
    local camPitch = -42.0
    local camYawRel = 0.0
    local fov = (defaultCamOffset and tonumber(defaultCamOffset.fov)) or 50.0

    local function isFiniteNumber(value)
        local number = tonumber(value)
        if not number or number ~= number or number == math.huge or number == -math.huge then
            return nil
        end
        return number
    end

    local function clamp(value, minValue, maxValue)
        return math.max(minValue, math.min(maxValue, value))
    end

    -- Offset de camera e local a bancada. Valores com dezenas de milhares sao
    -- residuos de configuracoes antigas que salvaram coordenadas de mundo (ou
    -- um handle invalido) como se fossem offsets locais.
    local storedX = defaultCamOffset and isFiniteNumber(defaultCamOffset.x)
    local storedY = defaultCamOffset and isFiniteNumber(defaultCamOffset.y)
    local storedZ = defaultCamOffset and isFiniteNumber(defaultCamOffset.z)
    local hasSafeStoredOffset = storedX and storedY and storedZ
        and math.abs(storedX) <= 25.0
        and math.abs(storedY) <= 25.0
        and math.abs(storedZ) <= 25.0

    if hasSafeStoredOffset then
        camRelX = storedX
        camRelY = storedY
        camRelZ = storedZ
        camPitch = isFiniteNumber(defaultCamOffset.rotX) or camPitch
        camYawRel = isFiniteNumber(defaultCamOffset.rotZ) or camYawRel
        fov = isFiniteNumber(defaultCamOffset.fov) or fov
    elseif defaultCamOffset and (defaultCamOffset.x or defaultCamOffset.y or defaultCamOffset.z) then
        notify(locales.main_title or "Crafting", "A configuracao antiga da camera era invalida e foi restaurada para um enquadramento seguro.", "warning")
    end

    camRelX = clamp(camRelX, -25.0, 25.0)
    camRelY = clamp(camRelY, -25.0, 25.0)
    camRelZ = clamp(camRelZ, -5.0, 25.0)
    camPitch = clamp(camPitch, -89.9, 25.0)
    fov = clamp(fov, 15.0, 115.0)

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", false)

    local function updateCam()
        camRelX = clamp(isFiniteNumber(camRelX) or centerRel.x, -25.0, 25.0)
        camRelY = clamp(isFiniteNumber(camRelY) or (centerRel.y - 0.75), -25.0, 25.0)
        camRelZ = clamp(isFiniteNumber(camRelZ) or (centerRel.z + 0.65), -5.0, 25.0)
        camPitch = clamp(isFiniteNumber(camPitch) or -42.0, -89.9, 25.0)
        camYawRel = (isFiniteNumber(camYawRel) or 0.0) % 360.0
        fov = clamp(isFiniteNumber(fov) or 50.0, 15.0, 115.0)

        local headingRad = degToRad(benchHeading)
        local forward = vector3(-math.sin(headingRad), math.cos(headingRad), 0.0)
        local right = vector3(math.cos(headingRad), math.sin(headingRad), 0.0)
        local worldPos = benchBaseCoords + right * camRelX + forward * camRelY + vector3(0.0, 0.0, camRelZ)
        local worldYaw = (benchHeading + camYawRel) % 360.0

        SetCamCoord(cam, worldPos.x, worldPos.y, worldPos.z)
        SetCamRot(cam, camPitch, 0.0, worldYaw, 2)
        SetCamFov(cam, fov)
    end

    updateCam()
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 300, true, true)

    notify(locales.main_title or "Crafting", "Fase 2/2: Posicione a câmera ao redor ou acima da bancada (V: Alterna Visão Zenital).", "inform")

    local done = false
    local cancelled = false
    local presetIdx = 1
    local pedPreviewVisible = true

    while not done do
        Wait(0)

        -- Manter o Ped fixado na posição exata do Gizmo e animando
        if testPed and DoesEntityExist(testPed) then
            if finalPedCoords then
                SetEntityCoordsNoOffset(testPed, finalPedCoords.x, finalPedCoords.y, finalPedCoords.z, false, false, false)
                if finalPedHeading then
                    SetEntityHeading(testPed, finalPedHeading)
                end
                FreezeEntityPosition(testPed, true)
            end
            if animDict and animName and not IsEntityPlayingAnim(testPed, animDict, animName, 3) then
                TaskPlayAnim(testPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
        end

        -- Manter esta camera como dona da renderizacao. Alem de IsCamActive,
        -- valide o handle realmente renderizado: outra camera pode continuar
        -- marcada como ativa durante o fim de uma transicao do Gizmo.
        local renderedCam = type(GetRenderingCam) == "function" and GetRenderingCam() or cam
        if not IsCamActive(cam) or renderedCam ~= cam then
            SetCamActive(cam, true)
            RenderScriptCams(true, false, 0, true, true)
        end

        DisableAllControlActions(0)
        HideHudComponentThisFrame(14)

        local mult = 1.0
        if IsDisabledControlPressed(0, 21) then -- SHIFT
            mult = 2.5
        end

        -- 1. Controle por Mouse
        local mouseX = GetDisabledControlNormal(0, 1) * 3.5
        local mouseY = GetDisabledControlNormal(0, 2) * 3.5

        if math.abs(mouseX) > 0.001 then
            camYawRel = (camYawRel - mouseX * 0.06 * mult) % 360.0
        end
        if math.abs(mouseY) > 0.001 then
            -- Pitch pode ir de +25° (nível da mesa) até -89.5° (visão zenital direto de cima)
            camPitch = math.max(-89.9, math.min(25.0, camPitch - mouseY * 0.04 * mult))
        end

        -- 2. Movimentação Frente / Trás com W / S
        if IsDisabledControlPressed(0, 32) then -- W -> Puxar para frente (aproximar da mesa / passar por cima)
            camRelY = camRelY + 0.015 * mult
        elseif IsDisabledControlPressed(0, 31) then -- S -> Afastar para trás
            camRelY = camRelY - 0.015 * mult
        end

        -- 3. Movimentação Esquerda / Direita com A / D
        if IsDisabledControlPressed(0, 34) then -- A -> Esquerda
            camRelX = camRelX - 0.015 * mult
        elseif IsDisabledControlPressed(0, 30) then -- D -> Direita
            camRelX = camRelX + 0.015 * mult
        end

        -- 4. Subir e Descer com Q / E
        if IsDisabledControlPressed(0, 38) then -- E -> Subir
            camRelZ = camRelZ + 0.015 * mult
        elseif IsDisabledControlPressed(0, 44) then -- Q -> Descer
            camRelZ = math.max(-0.5, camRelZ - 0.015 * mult)
        end

        -- 5. Scroll do Mouse (Dolly ou FOV)
        local isAltPressed = IsDisabledControlPressed(0, 19) or IsControlPressed(0, 19) -- ALT
        local isCtrlPressed = IsDisabledControlPressed(0, 36) or IsControlPressed(0, 36) -- CTRL

        if isAltPressed or isCtrlPressed then
            if IsDisabledControlJustPressed(0, 241) then -- Scroll Up -> Diminui FOV (mais zoom)
                fov = math.max(15.0, fov - 2.5 * mult)
            elseif IsDisabledControlJustPressed(0, 242) then -- Scroll Down -> Aumenta FOV (abre laterais)
                fov = math.min(115.0, fov + 2.5 * mult)
            end
        else
            if IsDisabledControlJustPressed(0, 241) then -- Scroll Up -> Aproxima altura/frente
                camRelZ = math.max(-0.2, camRelZ - 0.04 * mult)
                camRelY = camRelY + 0.03 * mult
            elseif IsDisabledControlJustPressed(0, 242) then -- Scroll Down -> Afasta altura/trás
                camRelZ = camRelZ + 0.04 * mult
                camRelY = camRelY - 0.03 * mult
            end
        end

        -- 6. Teclas de Atalho de FOV:
        -- Z / Seta Esquerda = Mais zoom (diminui FOV)
        -- X / Seta Direita = Abre laterais (aumenta FOV)
        if IsDisabledControlPressed(0, 174) or IsDisabledControlPressed(0, 20) then
            fov = math.max(15.0, fov - 0.4 * mult)
        elseif IsDisabledControlPressed(0, 175) or IsDisabledControlPressed(0, 73) then
            fov = math.min(115.0, fov + 0.4 * mult)
        end

        -- 7. Tecla V (Alternar Presets Rápidos: Zenital Top-Down 90°, Superior Inclinada 45°, Frontal 20°)
        if IsDisabledControlJustPressed(0, 0) or IsDisabledControlJustPressed(0, 75) then -- V
            presetIdx = (presetIdx % 3) + 1
            if presetIdx == 1 then
                -- Preset 1: Visão Zenital 90° (De Cima para Baixo, centralizada no tampo da mesa)
                camRelX = centerRel.x
                camRelY = centerRel.y
                camRelZ = centerRel.z + 0.90
                camPitch = -89.5
                camYawRel = 0.0
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            elseif presetIdx == 2 then
                -- Preset 2: Visão Inclinada Superior (45°)
                camRelX = centerRel.x
                camRelY = centerRel.y - 0.65
                camRelZ = centerRel.z + 0.60
                camPitch = -45.0
                camYawRel = 0.0
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            else
                -- Preset 3: Visão Frontal (20°)
                camRelX = centerRel.x
                camRelY = centerRel.y - 0.85
                camRelZ = centerRel.z + 0.35
                camPitch = -20.0
                camYawRel = 0.0
                PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
            end
        end

        -- 8. Tecla R: Resetar FOV (50.0°)
        if IsDisabledControlJustPressed(0, 45) then -- R
            fov = 50.0
            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
        end

        -- H alterna o ped de teste, útil para conferir a composição e também
        -- ajustar a DUI sem que o corpo esconda a mesa.
        if IsDisabledControlJustPressed(0, 74) and testPed and DoesEntityExist(testPed) then
            pedPreviewVisible = not pedPreviewVisible
            SetEntityVisible(testPed, pedPreviewVisible, false)
            PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
        end

        updateCam()

        setText(string.format(
            "Posicionamento da Câmera na Bancada\n" ..
            "Pos: [X: %.2f | Y: %.2f | Z: %.2f]  |  Pitch: %.1f°  |  FOV: %.1f°\n" ..
            "[W/S] Frente/Trás  |  [A/D] Esquerda/Direita  |  [Q/E] Subir/Descer\n" ..
            "[Mouse] Olhar / Inclinar (até -89.5° de cima para baixo)\n" ..
            "[V] Alternar Presets (Zenital 90° / Inclinada 45° / Frontal)\n" ..
            "[ALT + Scroll ou Z/X] Ajustar FOV  |  [R] Resetar FOV (50°)  |  [H] Ped\n" ..
            "[SHIFT] Acelerar  |  [ENTER] Salvar  |  [BACKSPACE] Cancelar",
            camRelX, camRelY, camRelZ, camPitch, fov
        ))

        if IsDisabledControlJustPressed(0, 201) then -- ENTER
            done = true
        elseif IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 202) then -- BACKSPACE / ESC
            done = true
            cancelled = true
        end
    end

    hideText()

    RenderScriptCams(false, true, 300, true, false)
    DestroyCam(cam, false)
    restoreCameraTunerPlayer()
    if testPed and DoesEntityExist(testPed) then
        SetEntityVisible(testPed, true, false)
    end

    if cancelled then
        if onCancel then onCancel() end
    else
        -- Os controles ja trabalham no espaco local da bancada. Salvar esse
        -- estado diretamente evita reler coordenadas de um handle substituido
        -- ou destruido por outra camera e converte-las novamente.
        local resultCamOffset = {
            x = tonumber(string.format("%.3f", camRelX)),
            y = tonumber(string.format("%.3f", camRelY)),
            z = tonumber(string.format("%.3f", camRelZ)),
            rotX = tonumber(string.format("%.1f", camPitch)),
            rotY = 0.0,
            rotZ = tonumber(string.format("%.1f", camYawRel)),
            fov = tonumber(string.format("%.1f", fov))
        }

        if onConfirm then onConfirm(resultCamOffset) end
    end
end

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        restoreCameraTunerPlayer()
    end
end)

-- Fluxo Principal do Construtor e Calibrador de Bancada
local function startBenchCreatorFlow(preselectedModel)
    local defaultName = preselectedModel and preselectedModel.label or "Bancada de Fabricação"
    local defaultProp = preselectedModel and preselectedModel.model or "gr_prop_gr_bench_02a"
    local isExisting = preselectedModel ~= nil

    local input = pr_lib.inputDialog("Construtor e Calibrador de Bancada DUI", {
        { type = 'input', label = "Nome da Bancada", default = defaultName, required = true, icon = "signature" },
        { type = 'input', label = "Modelo do Prop", default = defaultProp, required = true, icon = "cube" },
        { 
            type = 'select', 
            label = "Modo de Calibração da DUI", 
            options = {
                { value = 'capture_4p', label = "Capturar 4 Pontos com Laser + Ajuste Fino de Altura" },
                { value = 'manual_coords', label = "Digitar Coordenadas / Offsets Manualmente" },
                { value = 'preset', label = "Usar Calibração Padrão (Tampo Central)" }
            },
            default = 'capture_4p',
            required = true 
        },
        { type = 'checkbox', label = "Salvar como Bancada Funcional Permanente no Mapa", checked = not isExisting },
    })

    if not input then return end

    local benchName = input[1]
    local propModel = input[2]
    local calibMode = input[3]
    local saveToWorld = input[4]

    -- 1. Posiciona o prop no mundo com o Gizmo 3D
    spawnAndPlaceProp(propModel, "Posicionar " .. benchName, function(propObj, benchCoords, benchHeading, confirmed)
        if not confirmed or not propObj then return end

        benchHeading = tonumber(benchHeading) or 0.0
        local finalVertices = nil
        local finalOffset = 0.035
        local relCenter = { x = 0.0, y = 0.0, z = 0.85, w = 0.0 }
        local scaleVal = preselectedModel and (preselectedModel.scale or 1.0) or 1.0

        local function finalizeModelAndSave()
            local modelSlug = preselectedModel and preselectedModel.slug or ('bench_' .. propModel:lower():gsub("[^%w_]", ""))
            local tempModel = {
                slug = modelSlug,
                label = benchName,
                model = propModel,
                center_offset = {
                    x = relCenter.x,
                    y = relCenter.y,
                    z = relCenter.z,
                    w = 0.0,
                    height_offset = finalOffset,
                    vertices = finalVertices
                },
                scale = scaleVal,
                anim_dict = preselectedModel and preselectedModel.anim_dict or 'anim@amb@board_room@diagram_blueprints@',
                anim_name = preselectedModel and preselectedModel.anim_name or 'idle_01_amy_skater_01',
                anim_offset = preselectedModel and preselectedModel.anim_offset or { x = -0.85, y = 0.0, z = 0.25 },
                cam_offset = preselectedModel and preselectedModel.cam_offset or { x = -0.15, y = 0.0, z = 0.65 }
            }

            local function saveModelToDbAndWorld()
                pr_lib.callback.trigger('forge-crafting:saveBenchModel', function(ok, err)
                    if ok then
                        notify(locales.main_title, "Modelo de bancada salvo com sucesso!", "success")

                        if saveToWorld then
                            local newData = {
                                craft_name = benchName,
                                prop = propModel,
                                model_slug = tempModel.slug,
                                jobrequire = false,
                                requireblip = false,
                                blip = nil,
                                jobs = nil,
                                propcoords = vector3(benchCoords.x, benchCoords.y, benchCoords.z),
                                heading = benchHeading,
                                jobenable = false,
                                blipenable = false
                            }
                            TriggerServerEvent("forge-crafting:CreateWorkShop", newData)
                            notify(locales.main_title, "Bancada criada e salva permanentemente no mapa!", "success")
                            Wait(200)
                            TriggerServerEvent("forge-crafting:Update")
                        end
                    else
                        notify(locales.main_title, err or "Erro ao salvar modelo.", "error")
                    end

                    if DoesEntityExist(propObj) and not saveToWorld then
                        DeleteObject(propObj)
                    end
                end, tempModel)
            end

            -- Perguntar se deseja prosseguir para o posicionamento do Ped e Câmera
            local wantPedAndCam = pr_lib.alertDialog({
                header = "Calibração: Ped & Câmera",
                content = "DUI calibrada com sucesso!\n\nDeseja posicionar a animação do Ped (Gizmo) e a Câmera (Freecam) agora?",
                centered = true,
                cancel = true,
                labels = { confirm = "Posicionar Ped & Câmera", cancel = "Salvar com Padrões" }
            })

            if wantPedAndCam == "confirm" then
                local streaming = pr_lib and pr_lib.fivem and pr_lib.fivem.streaming
                local gizmoApi = (pr_lib and pr_lib.fivem and pr_lib.fivem.gizmo) or (pr_lib and pr_lib.gizmo)

                -- 1. Carregar animação
                local animDict = tempModel.anim_dict or 'anim@amb@board_room@diagram_blueprints@'
                local animName = tempModel.anim_name or 'idle_01_amy_skater_01'
                if streaming and streaming.requestAnimDict then
                    streaming.requestAnimDict(animDict, 3000)
                else
                    RequestAnimDict(animDict)
                    while not HasAnimDictLoaded(animDict) do Wait(10) end
                end

                -- 2. Spawna Ped de teste na frente da bancada
                local benchForward = vector3(-math.sin(degToRad(benchHeading)), math.cos(degToRad(benchHeading)), 0.0)
                local initialPedCoords = benchCoords - benchForward * 1.05
                local playerModel = GetEntityModel(PlayerPedId())
                local testPed = CreatePed(4, playerModel, initialPedCoords.x, initialPedCoords.y, initialPedCoords.z, benchHeading, false, true)
                SetEntityHeading(testPed, benchHeading)
                SetEntityInvincible(testPed, true)
                SetBlockingOfNonTemporaryEvents(testPed, true)
                FreezeEntityPosition(testPed, true)
                TaskPlayAnim(testPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

                -- 3. Criar DUI na bancada para visualização contínua
                local calibP1, calibP2, calibP3, calibP4
                local cOffset = tempModel.center_offset
                local hOffset = tonumber(cOffset.height_offset) or 0.035
                local centerCoords = getRelativeOffset(benchCoords, benchHeading, cOffset) + vector3(0.0, 0.0, hOffset)

                if cOffset.vertices and #cOffset.vertices == 4 then
                    local pp1 = getRelativeOffset(benchCoords, benchHeading, cOffset.vertices[1])
                    local pp2 = getRelativeOffset(benchCoords, benchHeading, cOffset.vertices[2])
                    local pp3 = getRelativeOffset(benchCoords, benchHeading, cOffset.vertices[3])
                    local pp4 = getRelativeOffset(benchCoords, benchHeading, cOffset.vertices[4])
                    local v1, v2, v3, v4 = offsetVertices({ pp1, pp2, pp3, pp4 }, hOffset)
                    centerCoords = (v1 + v2 + v3 + v4) * 0.25
                    calibP1, calibP2, calibP3, calibP4 = v1, v2, v3, v4
                else
                    local headingRad2 = degToRad(benchHeading)
                    local fwd2 = vector3(-math.sin(headingRad2), math.cos(headingRad2), 0.0)
                    local rgt2 = vector3(math.cos(headingRad2), math.sin(headingRad2), 0.0)
                    local sc = tempModel.scale or 1.0
                    local halfW = 0.55 * sc
                    local halfH = 0.23 * sc
                    calibP1 = centerCoords - rgt2 * halfW + fwd2 * halfH
                    calibP2 = centerCoords + rgt2 * halfW + fwd2 * halfH
                    calibP3 = centerCoords + rgt2 * halfW - fwd2 * halfH
                    calibP4 = centerCoords - rgt2 * halfW - fwd2 * halfH
                end

                local calibScreen = CreateCalibrationDuiScreen(calibP1, calibP2, calibP3, calibP4, 'forge_crafting_buildertool')

                -- FASE 1: Gizmo no Ped
                notify(locales.main_title or "Crafting", "Fase 1/2: Ajuste a posição do Ped com o Gizmo (DUI visível na mesa).", "inform")

                local confirmedResult, finalResult = gizmoApi.await(testPed, {
                    title = "Ajuste o Ped na Bancada com o Gizmo (TAB: Precisão | ENTER: Confirmar)",
                    offset = vector3(0.0, 0.0, 0.0),
                    precisionMode = false,
                    precisionSpeed = 1.0,
                    allowFreeCameraToggle = true,
                    restoreOnCancel = false,
                    ui = true,
                })

                local result = confirmedResult or finalResult or { confirmed = false }
                if not result.confirmed then
                    notify(locales.main_title or "Crafting", "Posicionamento do ped cancelado. Salvando com padrões...", "inform")
                    DestroyCalibrationDuiScreen(calibScreen)
                    if DoesEntityExist(testPed) then DeleteEntity(testPed) end
                    saveModelToDbAndWorld()
                    return
                end

                local finalPedCoords = result.coords or GetEntityCoords(testPed)
                local finalPedRot = result.rotation or GetEntityRotation(testPed, 2)
                local finalPedHeading = (type(finalPedRot) == 'vector3' and finalPedRot.z) or (type(finalPedRot) == 'table' and (finalPedRot.z or finalPedRot[3])) or GetEntityHeading(testPed)
                finalPedHeading = tonumber(finalPedHeading) or benchHeading

                SetEntityCoordsNoOffset(testPed, finalPedCoords.x, finalPedCoords.y, finalPedCoords.z, false, false, false)
                SetEntityHeading(testPed, finalPedHeading)
                FreezeEntityPosition(testPed, true)
                TaskPlayAnim(testPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

                -- FASE 2: Câmera focada na Bancada (Órbita e Altura)
                local benchRef = (DoesEntityExist(propObj) and propObj) or benchCoords
                startBenchCameraTuner(
                    benchRef,
                    benchHeading,
                    centerCoords,
                    tempModel.cam_offset,
                    testPed,
                    animDict,
                    animName,
                    finalPedCoords,
                    finalPedHeading,
                    function(resultCamOffset)
                        DestroyCalibrationDuiScreen(calibScreen)
                        if DoesEntityExist(testPed) then DeleteEntity(testPed) end

                        local pedRel = reverseRelativeOffset(benchRef, benchHeading, finalPedCoords)
                        local pedRelHeading = (finalPedHeading - benchHeading) % 360.0

                        tempModel.anim_offset = {
                            x = tonumber(string.format("%.3f", pedRel.x)),
                            y = tonumber(string.format("%.3f", pedRel.y)),
                            z = tonumber(string.format("%.3f", pedRel.z)),
                            heading = tonumber(string.format("%.1f", pedRelHeading))
                        }
                        tempModel.cam_offset = resultCamOffset

                        saveModelToDbAndWorld()
                    end,
                    function()
                        notify(locales.main_title or "Crafting", "Configuração da câmera cancelada. Salvando com padrões...", "inform")
                        DestroyCalibrationDuiScreen(calibScreen)
                        if DoesEntityExist(testPed) then DeleteEntity(testPed) end
                        saveModelToDbAndWorld()
                    end
                )
                return
            else
                saveModelToDbAndWorld()
            end
        end

        -- 2. Modo Capturar 4 Pontos com Laser + Ajuste Fino
        if calibMode == 'capture_4p' then
            notify(locales.main_title, "Mire no prop da bancada para marcar os 4 cantos da face da mesa.", "inform")
            local ok, captured = captureBenchVertices()
            if ok and captured and #captured == 4 then
                notify(locales.main_title, "Pontos capturados! Ajuste a altura fina da DUI usando as Setas.", "inform")
                local tunedOk, tunedOffset = fineTuneBenchHeight(captured, 0.035)
                finalOffset = tunedOk and tunedOffset or 0.035

                -- Converte as coordenadas globais capturadas em OFFSETS RELATIVOS AO PROP
                local benchRef = (DoesEntityExist(propObj) and propObj) or benchCoords
                local relV1 = serialVector(reverseRelativeOffset(benchRef, benchHeading, captured[1]))
                local relV2 = serialVector(reverseRelativeOffset(benchRef, benchHeading, captured[2]))
                local relV3 = serialVector(reverseRelativeOffset(benchRef, benchHeading, captured[3]))
                local relV4 = serialVector(reverseRelativeOffset(benchRef, benchHeading, captured[4]))

                finalVertices = { relV1, relV2, relV3, relV4 }

                local cPoint = (captured[1] + captured[2] + captured[3] + captured[4]) * 0.25
                local cRel = reverseRelativeOffset(benchCoords, benchHeading, cPoint)
                relCenter = {
                    x = tonumber(('%0.3f'):format(cRel.x)),
                    y = tonumber(('%0.3f'):format(cRel.y)),
                    z = tonumber(('%0.3f'):format(cRel.z)),
                    w = 0.0
                }

                local wDist = #(captured[2] - captured[1])
                scaleVal = math.max(0.4, math.min(2.5, wDist / 1.0))

                finalizeModelAndSave()
            else
                notify(locales.main_title, "Captura cancelada. Prop removido.", "inform")
                if DoesEntityExist(propObj) then DeleteObject(propObj) end
            end
        end

        -- 3. Modo Digitar Coordenadas / Offsets Manualmente
        if calibMode == 'manual_coords' then
            local manualDialog = pr_lib.inputDialog("Coordenadas / Offsets da DUI no Prop", {
                { type = 'number', label = "Offset X (Lateral)", default = 0.0, precision = 3, step = 0.01 },
                { type = 'number', label = "Offset Y (Profundidade)", default = 0.0, precision = 3, step = 0.01 },
                { type = 'number', label = "Offset Z (Altura do Tampo)", default = 0.85, precision = 3, step = 0.01 },
                { type = 'number', label = "Ajuste Fino de Altura (Z Extra)", default = 0.035, precision = 3, step = 0.005 },
                { type = 'number', label = "Escala da Tela DUI", default = scaleVal or 1.0, precision = 2, step = 0.05, min = 0.2, max = 3.0 },
            })

            if manualDialog then
                relCenter = {
                    x = tonumber(manualDialog[1]) or 0.0,
                    y = tonumber(manualDialog[2]) or 0.0,
                    z = tonumber(manualDialog[3]) or 0.85,
                    w = 0.0
                }
                finalOffset = tonumber(manualDialog[4]) or 0.035
                scaleVal = tonumber(manualDialog[5]) or 1.0
                finalizeModelAndSave()
            else
                if DoesEntityExist(propObj) then DeleteObject(propObj) end
            end
        end

        -- 4. Modo Preset Central
        if calibMode == 'preset' then
            relCenter = { x = 0.0, y = 0.0, z = 0.85, w = 0.0 }
            finalOffset = 0.035
            scaleVal = 1.0
            finalizeModelAndSave()
        end
    end)
end

-- =====================================================
--  Gerenciador de Modelos de Bancadas (Menu Contextual)
-- =====================================================

local function testBenchModelPreview(m)
    local ped = PlayerPedId()
    local spawnCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.8, -0.95)
    local spawnHeading = (GetEntityHeading(ped) + 180.0) % 360.0

    local streaming = pr_lib.fivem and pr_lib.fivem.streaming
    local modelHash = joaat(m.model)
    if streaming and streaming.requestModel then
        streaming.requestModel(modelHash, 3000)
    else
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(10) end
    end

    local testProp = CreateObjectNoOffset(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, true, false)
    SetEntityHeading(testProp, spawnHeading)
    FreezeEntityPosition(testProp, true)
    SetEntityInvincible(testProp, true)

    local tempBench = {
        id = 99998,
        name = m.label or "Bancada Teste",
        coords = vector4(spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnHeading),
        model = m.model,
        model_slug = m.slug,
        bench_model = m
    }

    StartBenchDuiSession(tempBench, {
        {
            item = "preview_item",
            item_label = "Visualização de Teste",
            time = 5,
            amount = 1,
            level = 0,
            recipe = {}
        }
    }, 10)

    CreateThread(function()
        while IsBenchDuiActive() do
            Wait(250)
        end
        if DoesEntityExist(testProp) then
            DeleteObject(testProp)
        end
        OpenBenchModelsMenu()
    end)
end

-- =====================================================
--  Posicionamento do Ped com GIZMO 3D & Câmera Livre
-- =====================================================

local function startGizmoPedAndCameraTuner(m)
    local playerPed = PlayerPedId()
    local pedCoords = GetEntityCoords(playerPed)
    local pedHeading = GetEntityHeading(playerPed)

    local forward = vector3(-math.sin(degToRad(pedHeading)), math.cos(degToRad(pedHeading)), 0.0)
    local benchBaseCoords = pedCoords + forward * 2.2
    local benchHeading = (pedHeading + 180.0) % 360.0

    local streaming = pr_lib and pr_lib.fivem and pr_lib.fivem.streaming
    local gizmoApi = (pr_lib and pr_lib.fivem and pr_lib.fivem.gizmo) or (pr_lib and pr_lib.gizmo)

    if not gizmoApi or not gizmoApi.await then
        notify(locales.main_title or "Crafting", "Gizmo 3D indisponível no pr_bridge.", "error")
        return
    end

    -- 1. Carregar prop e criar mesa
    local modelHash = joaat(m.model)
    if streaming and streaming.requestModel then
        streaming.requestModel(modelHash, 3000)
    else
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(10) end
    end

    local testProp = CreateObjectNoOffset(modelHash, benchBaseCoords.x, benchBaseCoords.y, benchBaseCoords.z, false, true, false)
    SetEntityHeading(testProp, benchHeading)
    FreezeEntityPosition(testProp, true)
    SetEntityInvincible(testProp, true)

    -- 2. Carregar animação
    local animDict = m.anim_dict or 'anim@amb@board_room@diagram_blueprints@'
    local animName = m.anim_name or 'idle_01_amy_skater_01'
    if streaming and streaming.requestAnimDict then
        streaming.requestAnimDict(animDict, 3000)
    else
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(10) end
    end

    -- 3. Spawna Ped de teste na frente da bancada
    local animOffset = m.anim_offset or {}
    local initialPedCoords
    local initialPedHeading = benchHeading

    if animOffset.x and animOffset.y and animOffset.z then
        initialPedCoords = getRelativeOffset(benchBaseCoords, benchHeading, animOffset)
        initialPedHeading = (benchHeading + (tonumber(animOffset.heading) or 0.0)) % 360.0
    else
        local benchForward = vector3(-math.sin(degToRad(benchHeading)), math.cos(degToRad(benchHeading)), 0.0)
        initialPedCoords = benchBaseCoords - benchForward * 1.05
    end

    local playerModel = GetEntityModel(playerPed)
    local testPed = CreatePed(4, playerModel, initialPedCoords.x, initialPedCoords.y, initialPedCoords.z, initialPedHeading, false, true)
    SetEntityHeading(testPed, initialPedHeading)
    SetEntityInvincible(testPed, true)
    SetBlockingOfNonTemporaryEvents(testPed, true)
    FreezeEntityPosition(testPed, true)
    TaskPlayAnim(testPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Calcular pontos e criar DUI na bancada para visualização contínua durante Ped e Câmera
    local cOffset = m.center_offset or { x = 0.0, y = 0.0, z = 0.85, w = 0.0 }
    local hOffset = tonumber(cOffset.height_offset) or 0.035
    local centerCoords = getRelativeOffset(benchBaseCoords, benchHeading, cOffset) + vector3(0.0, 0.0, hOffset)
    local calibP1, calibP2, calibP3, calibP4

    if cOffset.vertices and #cOffset.vertices == 4 then
        local pp1 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[1])
        local pp2 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[2])
        local pp3 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[3])
        local pp4 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[4])
        local v1, v2, v3, v4 = offsetVertices({ pp1, pp2, pp3, pp4 }, hOffset)
        centerCoords = (v1 + v2 + v3 + v4) * 0.25
        calibP1, calibP2, calibP3, calibP4 = v1, v2, v3, v4
    else
        local headingRad2 = degToRad(benchHeading)
        local fwd2 = vector3(-math.sin(headingRad2), math.cos(headingRad2), 0.0)
        local rgt2 = vector3(math.cos(headingRad2), math.sin(headingRad2), 0.0)
        local sc = m.scale or 1.0
        local halfW = 0.55 * sc
        local halfH = 0.23 * sc
        calibP1 = centerCoords - rgt2 * halfW + fwd2 * halfH
        calibP2 = centerCoords + rgt2 * halfW + fwd2 * halfH
        calibP3 = centerCoords + rgt2 * halfW - fwd2 * halfH
        calibP4 = centerCoords - rgt2 * halfW - fwd2 * halfH
    end

    local calibScreen = CreateCalibrationDuiScreen(calibP1, calibP2, calibP3, calibP4, 'forge_crafting_camtool')

    -- FASE 1: Gizmo no Ped
    notify(locales.main_title or "Crafting", "Fase 1/2: Ajuste a posição e ângulo do Ped com o Gizmo 3D (DUI visível na bancada).", "inform")

    local confirmedResult, finalResult = gizmoApi.await(testPed, {
        title = "Ajuste o Ped na Bancada com o Gizmo (TAB: Precisão | ENTER: Confirmar)",
        offset = vector3(0.0, 0.0, 0.0),
        precisionMode = false,
        precisionSpeed = 1.0,
        allowFreeCameraToggle = true,
        restoreOnCancel = false,
        ui = true,
    })

    local result = confirmedResult or finalResult or { confirmed = false }
    if not result.confirmed then
        notify(locales.main_title or "Crafting", "Configuração cancelada.", "inform")
        DestroyCalibrationDuiScreen(calibScreen)
        if DoesEntityExist(testPed) then DeleteEntity(testPed) end
        if DoesEntityExist(testProp) then DeleteObject(testProp) end
        OpenBenchModelsMenu()
        return
    end

    local finalPedCoords = result.coords or GetEntityCoords(testPed)
    local finalPedRot = result.rotation or GetEntityRotation(testPed, 2)
    local finalPedHeading = (type(finalPedRot) == 'vector3' and finalPedRot.z) or (type(finalPedRot) == 'table' and (finalPedRot.z or finalPedRot[3])) or GetEntityHeading(testPed)
    finalPedHeading = tonumber(finalPedHeading) or benchHeading

    SetEntityCoordsNoOffset(testPed, finalPedCoords.x, finalPedCoords.y, finalPedCoords.z, false, false, false)
    SetEntityHeading(testPed, finalPedHeading)
    FreezeEntityPosition(testPed, true)
    TaskPlayAnim(testPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)

    -- FASE 2: Câmera focada na Bancada (Órbita e Altura)
    startBenchCameraTuner(
        benchBaseCoords,
        benchHeading,
        centerCoords,
        m.cam_offset,
        testPed,
        animDict,
        animName,
        finalPedCoords,
        finalPedHeading,
        function(resultCamOffset)
            DestroyCalibrationDuiScreen(calibScreen)
            if DoesEntityExist(testPed) then DeleteEntity(testPed) end
            if DoesEntityExist(testProp) then DeleteObject(testProp) end

            local pedRel = reverseRelativeOffset(benchBaseCoords, benchHeading, finalPedCoords)
            local pedRelHeading = (finalPedHeading - benchHeading) % 360.0

            m.anim_offset = {
                x = tonumber(string.format("%.3f", pedRel.x)),
                y = tonumber(string.format("%.3f", pedRel.y)),
                z = tonumber(string.format("%.3f", pedRel.z)),
                heading = tonumber(string.format("%.1f", pedRelHeading))
            }
            m.cam_offset = resultCamOffset

            pr_lib.callback.trigger('forge-crafting:saveBenchModel', function(ok, err)
                if ok then
                    notify(locales.main_title or "Crafting", "Ped e Câmera salvos com sucesso!", "success")
                else
                    notify(locales.main_title or "Crafting", err or "Erro ao salvar modelo.", "error")
                end
                OpenBenchModelsMenu()
            end, m)
        end,
        function()
            notify(locales.main_title or "Crafting", "Configuração da câmera cancelada.", "inform")
            DestroyCalibrationDuiScreen(calibScreen)
            if DoesEntityExist(testPed) then DeleteEntity(testPed) end
            if DoesEntityExist(testProp) then DeleteObject(testProp) end
            OpenBenchModelsMenu()
        end
    )
end

local function startGizmoWeaponTuner(m)
    local streaming = pr_lib and pr_lib.fivem and pr_lib.fivem.streaming
    local gizmoApi = (pr_lib and pr_lib.fivem and pr_lib.fivem.gizmo) or (pr_lib and pr_lib.gizmo)

    if not gizmoApi or not gizmoApi.await then
        notify(locales.main_title or "Crafting", "Gizmo 3D indisponível no pr_bridge.", "error")
        return openModelDetailMenu(m)
    end

    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)
    local pHeading = GetEntityHeading(playerPed)

    -- 1. Carregar prop da bancada
    local propModel = m.model
    local modelHash = type(propModel) == 'string' and joaat(propModel) or propModel

    if streaming and streaming.requestModel then
        streaming.requestModel(modelHash, 3000)
    else
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do Wait(10) end
    end

    local fwd = vector3(-math.sin(degToRad(pHeading)), math.cos(degToRad(pHeading)), 0.0)
    local benchBaseCoords = pCoords + fwd * 1.65
    local benchHeading = (pHeading + 180.0) % 360.0

    local testProp = CreateObjectNoOffset(modelHash, benchBaseCoords.x, benchBaseCoords.y, benchBaseCoords.z, false, true, false)
    SetEntityHeading(testProp, benchHeading)
    FreezeEntityPosition(testProp, true)
    SetEntityInvincible(testProp, true)

    -- 2. Calcular pontos e criar DUI com a blueprint da bancada de upgrades
    local cOffset = m.center_offset or { x = 0.0, y = 0.0, z = 0.85, w = 0.0 }
    local hOffset = tonumber(cOffset.height_offset) or 0.035
    local centerCoords = getRelativeOffset(benchBaseCoords, benchHeading, cOffset) + vector3(0.0, 0.0, hOffset)
    local calibP1, calibP2, calibP3, calibP4

    if cOffset.vertices and #cOffset.vertices == 4 then
        local pp1 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[1])
        local pp2 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[2])
        local pp3 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[3])
        local pp4 = getRelativeOffset(benchBaseCoords, benchHeading, cOffset.vertices[4])
        local v1, v2, v3, v4 = offsetVertices({ pp1, pp2, pp3, pp4 }, hOffset)
        centerCoords = (v1 + v2 + v3 + v4) * 0.25
        calibP1, calibP2, calibP3, calibP4 = v1, v2, v3, v4
    else
        local headingRad2 = degToRad(benchHeading)
        local fwd2 = vector3(-math.sin(headingRad2), math.cos(headingRad2), 0.0)
        local rgt2 = vector3(math.cos(headingRad2), math.sin(headingRad2), 0.0)
        local sc = m.scale or 1.0
        local halfW = 0.55 * sc
        local halfH = 0.23 * sc
        calibP1 = centerCoords - rgt2 * halfW + fwd2 * halfH
        calibP2 = centerCoords + rgt2 * halfW + fwd2 * halfH
        calibP3 = centerCoords + rgt2 * halfW - fwd2 * halfH
        calibP4 = centerCoords - rgt2 * halfW - fwd2 * halfH
    end

    local calibScreen = CreateUpgradeCalibrationDuiScreen(calibP1, calibP2, calibP3, calibP4, 'forge_crafting_weapontool')

    -- 3. Carregar modelo da arma de teste (Carabina Especial MK2)
    local weaponHash = joaat("WEAPON_CARBINERIFLE_MK2")
    RequestWeaponAsset(weaponHash, 31, 0)
    local timeout = GetGameTimer() + 2500
    while not HasWeaponAssetLoaded(weaponHash) and GetGameTimer() < timeout do
        Wait(10)
    end

    -- Posição e rotação inicial da arma
    local initialWeaponCoords
    local initialRotX = 0.0
    local initialRotY = 0.0
    local initialRotZ = (benchHeading + 90.0) % 360.0

    if m.weapon_offset and m.weapon_offset.x then
        initialWeaponCoords = getRelativeOffset(benchBaseCoords, benchHeading, m.weapon_offset)
        initialRotX = tonumber(m.weapon_offset.rotX) or 0.0
        initialRotY = tonumber(m.weapon_offset.rotY) or 0.0
        initialRotZ = ((tonumber(m.weapon_offset.rotZ) or 0.0) + benchHeading) % 360.0
    else
        initialWeaponCoords = centerCoords + vector3(0.0, 0.0, 0.035)
    end

    local weaponObj = CreateWeaponObject(weaponHash, 1, initialWeaponCoords.x, initialWeaponCoords.y, initialWeaponCoords.z, true, 1.0, 0)
    SetEntityCollision(weaponObj, false, false)
    FreezeEntityPosition(weaponObj, true)
    SetEntityRotation(weaponObj, initialRotX, initialRotY, initialRotZ, 2, true)

    notify(locales.main_title or "Crafting", "Ajuste a posição e ângulo da arma com o Gizmo 3D (R: Mover/Girar | TAB: Precisão | ENTER: Confirmar).", "inform")

    local confirmedResult, finalResult = gizmoApi.await(weaponObj, {
        title = "Posicione e Gire a Arma na Mesa (R: Mover/Girar | TAB: Precisão | ENTER: Salvar)",
        offset = vector3(0.0, 0.0, 0.0),
        precisionMode = false,
        precisionSpeed = 0.5,
        allowFreeCameraToggle = true,
        restoreOnCancel = false,
        ui = true,
    })

    local result = confirmedResult or finalResult or { confirmed = false }
    if not result.confirmed then
        notify(locales.main_title or "Crafting", "Calibração da arma cancelada.", "inform")
        DestroyCalibrationDuiScreen(calibScreen)
        if DoesEntityExist(weaponObj) then DeleteEntity(weaponObj) end
        if DoesEntityExist(testProp) then DeleteObject(testProp) end
        openModelDetailMenu(m)
        return
    end

    local finalCoords = result.coords or GetEntityCoords(weaponObj)
    local finalRot = result.rotation or GetEntityRotation(weaponObj, 2)
    local fRotX = (type(finalRot) == 'vector3' and finalRot.x) or (type(finalRot) == 'table' and (finalRot.x or finalRot[1])) or 0.0
    local fRotY = (type(finalRot) == 'vector3' and finalRot.y) or (type(finalRot) == 'table' and (finalRot.y or finalRot[2])) or 0.0
    local fRotZ = (type(finalRot) == 'vector3' and finalRot.z) or (type(finalRot) == 'table' and (finalRot.z or finalRot[3])) or benchHeading

    local weaponRel = reverseRelativeOffset(testProp, benchHeading, finalCoords)
    local weaponRelRotZ = (fRotZ - benchHeading) % 360.0

    m.weapon_offset = {
        x = tonumber(string.format("%.3f", weaponRel.x)),
        y = tonumber(string.format("%.3f", weaponRel.y)),
        z = tonumber(string.format("%.3f", weaponRel.z)),
        rotX = tonumber(string.format("%.1f", fRotX)),
        rotY = tonumber(string.format("%.1f", fRotY)),
        rotZ = tonumber(string.format("%.1f", weaponRelRotZ)),
    }

    DestroyCalibrationDuiScreen(calibScreen)
    if DoesEntityExist(weaponObj) then DeleteEntity(weaponObj) end
    if DoesEntityExist(testProp) then DeleteObject(testProp) end

    pr_lib.callback.trigger('forge-crafting:saveBenchModel', function(ok, err)
        if ok then
            notify(locales.main_title or "Crafting", "Posicionamento e rotação da arma salvos com sucesso!", "success")
        else
            notify(locales.main_title or "Crafting", err or "Erro ao salvar modelo.", "error")
        end
        openModelDetailMenu(m)
    end, m)
end

local function openModelDetailMenu(m)
    local isDefault = m.slug == 'default'

    local options = {
        {
            title = "Posicionar e Girar Arma na Mesa (Gizmo 3D)",
            description = "Ajuste milimétrico da posição e rotação 3D da arma na bancada de upgrades com o Gizmo 3D.",
            icon = "gun",
            arrow = true,
            onSelect = function()
                startGizmoWeaponTuner(m)
            end
        },
        {
            title = "Posicionar Ped (Gizmo) e Câmera com FOV",
            description = "Ajuste o ped com o Gizmo 3D e configure o enquadramento da câmera e FOV (zoom e abertura lateral) com a DUI visível.",
            icon = "street-view",
            arrow = true,
            onSelect = function()
                startGizmoPedAndCameraTuner(m)
            end
        },
        {
            title = "Calibrar Tela DUI no Prop (4 Pontos + Altura)",
            description = "Abre o Gizmo 3D e a ferramenta de 4 pontos + ajuste fino de altura para posicionar a tela da DUI.",
            icon = "crosshairs",
            arrow = true,
            onSelect = function()
                startBenchCreatorFlow(m)
            end
        },
        {
            title = "Testar Visualização da DUI",
            description = "Spawna a bancada na sua frente temporariamente com a câmera e DUI ativas para testar.",
            icon = "eye",
            arrow = true,
            onSelect = function()
                testBenchModelPreview(m)
            end
        },
        {
            title = "Ajustar FOV da Câmera (Ângulo de Visão)",
            description = string.format("FOV Atual: %.1f°. Aumente para abrir mais as laterais da câmera ou diminua para aproximar o zoom.", (m.cam_offset and tonumber(m.cam_offset.fov)) or 50.0),
            icon = "camera",
            arrow = true,
            metadata = {
                { label = "FOV Atual", value = string.format("%.1f°", (m.cam_offset and tonumber(m.cam_offset.fov)) or 50.0) }
            },
            onSelect = function()
                local curFov = (m.cam_offset and tonumber(m.cam_offset.fov)) or 50.0
                local input = pr_lib.inputDialog("Ajustar FOV da Câmera", {
                    { 
                        type = 'slider', 
                        label = "FOV (Graus) - Menor = Zoom / Maior = Abre Laterais", 
                        default = curFov, 
                        min = 20.0, 
                        max = 110.0, 
                        step = 1.0,
                        description = "Padrão: 50°. Valores acima de 65° abrem mais a visão lateral da bancada."
                    }
                })
                if not input then return openModelDetailMenu(m) end

                if not m.cam_offset then m.cam_offset = {} end
                m.cam_offset.fov = tonumber(string.format("%.1f", input[1]))

                pr_lib.callback.trigger('forge-crafting:saveBenchModel', function(ok, err)
                    if ok then
                        notify(locales.main_title or "Crafting", string.format("FOV da câmera atualizado para %.1f°!", m.cam_offset.fov), "success")
                    else
                        notify(locales.main_title or "Crafting", err or "Erro ao salvar FOV.", "error")
                    end
                    openModelDetailMenu(m)
                end, m)
            end
        },
        {
            title = "Editar Animação & Prop",
            description = "Altera o modelo do prop, dicionário e nome da animação.",
            icon = "edit",
            arrow = true,
            onSelect = function()
                local editDialog = pr_lib.inputDialog("Editar: " .. (m.label or m.slug), {
                    { type = 'input', label = "Nome / Rótulo Amigável", default = m.label, required = true },
                    { type = 'input', label = "Modelo do Prop GTA", default = m.model, required = true },
                    { type = 'input', label = "Dicionário de Animação", default = m.anim_dict or 'anim@amb@board_room@diagram_blueprints@', required = true },
                    { type = 'input', label = "Nome da Animação", default = m.anim_name or 'idle_01_amy_skater_01', required = true },
                })
                if not editDialog then return openModelDetailMenu(m) end

                m.label = editDialog[1]
                m.model = editDialog[2]
                m.anim_dict = editDialog[3]
                m.anim_name = editDialog[4]

                pr_lib.callback.trigger('forge-crafting:saveBenchModel', function(ok, err)
                    if ok then
                        notify(locales.main_title or "Crafting", "Modelo atualizado com sucesso!", "success")
                    else
                        notify(locales.main_title or "Crafting", err or "Erro ao atualizar modelo.", "error")
                    end
                    OpenBenchModelsMenu()
                end, m)
            end
        }
    }

    if not isDefault then
        options[#options + 1] = {
            title = "Excluir Modelo",
            description = "Remove este modelo de bancada permanentemente do sistema.",
            icon = "trash",
            arrow = true,
            onSelect = function()
                local confirm = pr_lib.alertDialog({
                    header = "Excluir Modelo de Bancada",
                    content = string.format("Tem certeza que deseja excluir o modelo '%s' (%s)?", m.label or m.slug, m.model),
                    centered = true,
                    cancel = true
                })
                if confirm == "confirm" then
                    pr_lib.callback.trigger('forge-crafting:deleteBenchModel', function(ok, err)
                        if ok then
                            notify(locales.main_title or "Crafting", "Modelo excluído com sucesso!", "success")
                        else
                            notify(locales.main_title or "Crafting", err or "Falha ao excluir modelo.", "error")
                        end
                        OpenBenchModelsMenu()
                    end, m.slug)
                else
                    openModelDetailMenu(m)
                end
            end
        }
    end

    pr_lib.RegisterContext({
        id = 'forge_crafting_bench_model_detail',
        title = m.label or m.slug,
        menu = 'forge_crafting_bench_models_menu',
        options = options
    })
    pr_lib.showContext('forge_crafting_bench_model_detail')
end

function OpenBenchModelsMenu()
    pr_lib.callback.trigger('forge-crafting:PermisionCheck', function(hasPerm)
        if not hasPerm then
            notify(locales.main_title or "Crafting", locales.insufficient_permission or "Sem permissão.", "error")
            return
        end

        pr_lib.callback.trigger('forge-crafting:getBenchModels', function(models)
            local options = {}

            -- 1. Opção para Cadastrar Novo Modelo
            options[#options + 1] = {
                title = "+ Cadastrar Novo Modelo de Bancada",
                description = "Define um novo prop, slug, animações e calibra a DUI no prop.",
                icon = "plus",
                arrow = true,
                onSelect = function()
                    local input = pr_lib.inputDialog("Novo Modelo de Bancada", {
                        { type = 'input', label = "Slug Único (identificador)", placeholder = "ex: gr_bench_02a", required = true, icon = "tag" },
                        { type = 'input', label = "Nome / Rótulo Amigável", placeholder = "ex: Bancada Bunker", required = true, icon = "signature" },
                        { type = 'input', label = "Modelo do Prop GTA", placeholder = "ex: gr_prop_gr_bench_02a", required = true, icon = "cube" },
                        { type = 'input', label = "Dicionário de Animação", default = "anim@amb@board_room@diagram_blueprints@", required = true },
                        { type = 'input', label = "Nome da Animação", default = "idle_01_amy_skater_01", required = true },
                        { type = 'number', label = "Escala da DUI", default = 1.0, precision = 2, step = 0.05, min = 0.2, max = 3.0 },
                    })

                    if not input then return OpenBenchModelsMenu() end

                    local newModel = {
                        slug = input[1]:lower():gsub("[^%w_]", ""),
                        label = input[2],
                        model = input[3],
                        anim_dict = input[4],
                        anim_name = input[5],
                        scale = tonumber(input[6]) or 1.0,
                        center_offset = { x = 0.0, y = 0.0, z = 0.85, w = 0.0 },
                        anim_offset = { x = -0.85, y = 0.0, z = 0.25 },
                        cam_offset = { x = -0.15, y = 0.0, z = 0.65 }
                    }

                    local calibChoice = pr_lib.alertDialog({
                        header = "Calibração 3D da DUI",
                        content = "Deseja entrar no Modo de Calibração 3D (Gizmo + Raycast 4 Pontos + Altura) agora para este modelo?",
                        centered = true,
                        cancel = true
                    })

                    if calibChoice == "confirm" then
                        startBenchCreatorFlow(newModel)
                    else
                        pr_lib.callback.trigger('forge-crafting:saveBenchModel', function(ok, err)
                            if ok then
                                notify(locales.main_title or "Crafting", "Modelo cadastrado com sucesso!", "success")
                            else
                                notify(locales.main_title or "Crafting", err or "Erro ao salvar modelo.", "error")
                            end
                            OpenBenchModelsMenu()
                        end, newModel)
                    end
                end
            }

            -- 2. Construtor Rápido com Gizmo & 4 Pontos
            options[#options + 1] = {
                title = "Construtor e Calibrador Rápido DUI",
                description = "Spawna prop no mundo, calibra a tela com Raycast e salva imediatamente.",
                icon = "drafting-compass",
                arrow = true,
                onSelect = function()
                    startBenchCreatorFlow()
                end
            }

            -- 3. Lista de Modelos Existentes
            for _, m in ipairs(models or {}) do
                local isCalibrated = m.center_offset and m.center_offset.vertices and #m.center_offset.vertices == 4
                local statusDesc = string.format("Prop: %s | DUI: %s", m.model, isCalibrated and "Calibrado (4 Pontos)" or "Padrão")

                options[#options + 1] = {
                    title = m.label or m.slug,
                    description = statusDesc,
                    icon = "cube",
                    arrow = true,
                    onSelect = function()
                        openModelDetailMenu(m)
                    end
                }
            end

            pr_lib.RegisterContext({
                id = 'forge_crafting_bench_models_menu',
                title = "Modelos de Bancadas DUI",
                menu = 'crafting_list',
                options = options
            })
            pr_lib.showContext('forge_crafting_bench_models_menu')
        end)
    end)
end

AddEventHandler('forge-crafting:BenchModelsMenu', function()
    OpenBenchModelsMenu()
end)

-- Registro de Comandos de Calibração e Modelos
local function registerBenchToolCommand(cmd, fn)
    RegisterCommand(cmd, function()
        pr_lib.callback.trigger('forge-crafting:PermisionCheck', function(hasPerm)
            if hasPerm then
                fn()
            else
                notify(locales.main_title, locales.insufficient_permission or "Sem permissão.", "error")
            end
        end)
    end, false)
end

registerBenchToolCommand("createbench", function() startBenchCreatorFlow() end)
registerBenchToolCommand("benchtool", function() startBenchCreatorFlow() end)
registerBenchToolCommand("calibratedui", function() startBenchCreatorFlow() end)
