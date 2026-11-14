local reportWindow, reportCount = GetGameTimer(), 0

local function reportClientError(context, err)
    local trace = debug.traceback(tostring(err), 2)
    print(("^1[rp_characters][CLIENT ERROR] %s | %s^7"):format(tostring(context), tostring(err):sub(1, 2000)))
    print("^1" .. trace:sub(1, 6000) .. "^7")

    local now = GetGameTimer()
    if now - reportWindow > 10000 then
        reportWindow, reportCount = now, 0
    end
    reportCount = reportCount + 1
end

local function tracebackHandler(err)
    return debug.traceback(tostring(err), 2)
end

local function guarded(context, callback)
    return function(...)
        local args = table.pack(...)
        local result = table.pack(xpcall(function()
            return callback(table.unpack(args, 1, args.n))
        end, tracebackHandler))
        if not result[1] then
            reportClientError(context, result[2])
            return nil
        end
        return table.unpack(result, 2, result.n)
    end
end

local originalRegisterNetEvent = RegisterNetEvent
local originalAddEventHandler = AddEventHandler
local originalCreateThread = CreateThread
local originalSetTimeout = SetTimeout
local originalRegisterNUICallback = RegisterNUICallback

RegisterNetEvent = function(name, callback)
    if type(callback) == "function" then
        return originalRegisterNetEvent(name, guarded("net-event:" .. tostring(name), callback))
    end
    return originalRegisterNetEvent(name, callback)
end

AddEventHandler = function(name, callback)
    if type(callback) == "function" then
        return originalAddEventHandler(name, guarded("event:" .. tostring(name), callback))
    end
    return originalAddEventHandler(name, callback)
end

CreateThread = function(callback)
    if type(callback) == "function" then
        return originalCreateThread(guarded("thread", callback))
    end
    return originalCreateThread(callback)
end

SetTimeout = function(msec, callback)
    if type(callback) == "function" then
        return originalSetTimeout(msec, guarded("timeout", callback))
    end
    return originalSetTimeout(msec, callback)
end

RegisterNUICallback = function(name, callback)
    if type(callback) == "function" then
        return originalRegisterNUICallback(name, guarded("nui:" .. tostring(name), callback))
    end
    return originalRegisterNUICallback(name, callback)
end

-- Character creator implementation consolidated in this file.
-- No runtime dependency on external p*.lua fragments.

-- All character client logic is embedded below; no split-file loader is used.

local isCreating = false
local charCamera = nil
local characterBootPending = false
local characterSessionReady = false
local characterBootFailed = false
local creationSubmissionPending = false
local creationSubmissionToken = 0
local selectWatchdogToken = 0

local function ForceScreenVisible()
    pcall(ShutdownLoadingScreen)
    pcall(ShutdownLoadingScreenNui)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCharacterSelection' })
    SendNUIMessage({ action = 'closeRegistration' })
    if charCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    ClearFocus()
    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end
    DoScreenFadeIn(400)
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
    end
    DisplayRadar(true)
end

local function FinishCharacterBoot()
    characterBootPending = false
    ForceScreenVisible()
end

local function ShowCharacterBootError(message)
    characterBootPending = false
    characterSessionReady = false
    characterBootFailed = true
    creationSubmissionPending = false
    creationSubmissionToken = creationSubmissionToken + 1
    ForceScreenVisible()
    -- Leave the player controllable so they are not stuck on a black frame.
    SetPlayerControl(PlayerId(), true, 0)
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
    end
    TriggerEvent('chat:addMessage', {
        color = { 255, 90, 90 },
        multiline = true,
        args = { 'LOS SANTOS RP', message or 'Le chargement du personnage a échoué. Consultez la console serveur (F8) et reconnectez-vous.' }
    })
end

-- First-login onboarding. Controls are intentionally simple and do not depend on
-- external UI resources: E = next, Q = previous, Backspace = finish/skip.
local tutorialActive = false
local tutorialStep = 1
local tutorialPages = {
    {
        title = 'BIENVENUE À LOS SANTOS',
        lines = {
            'Bienvenue dans la ville ! Ton personnage commence une nouvelle histoire.',
            'Prends le temps de découvrir la ville et de rencontrer les autres habitants.',

            'Le plus important : joue ton personnage et laisse vivre les scènes RP.'
        }
    },
    {
        title = 'TON INVENTAIRE',
        lines = {
            'Appuie sur F2 pour ouvrir ton inventaire.',
            'Tu peux consulter tes objets et utiliser les objets autorisés.',
            'Tu peux donner ou déposer certains objets depuis cette interface.'
        }
    },
    {
        title = 'TON ARGENT',
        lines = {
            'Tu commences avec 2 500 $ en poche et 10 000 $ en banque.',
            'Appuie sur E devant un guichet bancaire ou un distributeur pour accéder à ton compte.',
            'Les principales banques sont indiquées sur ta carte.'
        }
    },
    {
        title = 'TROUVER UN MÉTIER',
        lines = {
            'Rends-toi au Pôle Emploi ou utilise /jobcenter pour découvrir les métiers.',
            'Le serveur propose de nombreux métiers civils et services publics.',
            'Une fois ton métier choisi, rends-toi sur son lieu de travail pour découvrir les interactions disponibles.'
        }
    },
    {
        title = 'INTERAGIR AVEC LES AUTRES',
        lines = {
            'Approche-toi des autres citoyens pour échanger et créer des scènes RP.',
            'Certaines actions nécessitent d’être proche de la personne concernée.',
            'Respecte les scènes en cours et privilégie toujours le dialogue.'
        }
    },
    {
        title = 'LES RÈGLES ESSENTIELLES',
        lines = {
            'Pas de méta-gaming : ne te sers pas d’informations obtenues hors RP.',
            'Pas de power-gaming : laisse aux autres la possibilité de réagir.',
            'Pas de free-kill : toute action doit avoir un contexte RP cohérent.'
        }
    },
    {
        title = 'TU ES PRÊT !',
        lines = {
            'Tu connais maintenant les premières bases pour commencer ton aventure.',
            'Explore la ville, trouve ton activité et construis ton histoire.',
            'Bon jeu et bienvenue sur Los Santos Roleplay !'
        }
    }
}

local function DrawTutorialText(value, x, y, scale, r, g, b, centered)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 245, g or 247, b or 250, 255)
    SetTextCentre(centered == true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(value)
    EndTextCommandDisplayText(x, y)
end

local function FinishTutorial()
    tutorialActive = false
    TriggerServerEvent('rp_characters:server:completeTutorial')
end

RegisterNetEvent('rp_characters:client:startTutorial', function()
    if tutorialActive then return end
    tutorialStep = 1
    tutorialActive = true

    CreateThread(function()
        while tutorialActive and IsPauseMenuActive() do Wait(250) end
        while tutorialActive do
            Wait(0)
            local page = tutorialPages[tutorialStep]
            if not page then
                FinishTutorial()
                break
            end

            DrawRect(0.5, 0.815, 0.68, 0.265, 8, 12, 20, 235)
            DrawRect(0.5, 0.69, 0.68, 0.012, 35, 145, 210, 255)
            DrawTutorialText('LOS SANTOS ROLEPLAY  •  GUIDE DU NOUVEAU', 0.5, 0.705, 0.30, 95, 185, 235, true)
            DrawTutorialText(page.title, 0.5, 0.745, 0.43, 255, 255, 255, true)

            for index, line in ipairs(page.lines) do
                DrawTutorialText(line, 0.19, 0.79 + ((index - 1) * 0.027), 0.30, 225, 230, 238, false)
            end

            DrawTutorialText(('ÉTAPE %d / %d'):format(tutorialStep, #tutorialPages), 0.19, 0.895, 0.27, 130, 145, 160, false)
            DrawTutorialText('Q  Précédent     E  Suivant     RETOUR  Passer', 0.81, 0.895, 0.27, 170, 195, 215, false)

            DisableControlAction(0, 38, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 177, true)

            if IsDisabledControlJustPressed(0, 38) then
                if tutorialStep >= #tutorialPages then
                    FinishTutorial()
                else
                    tutorialStep = tutorialStep + 1
                end
            elseif IsDisabledControlJustPressed(0, 44) then
                tutorialStep = math.max(1, tutorialStep - 1)
            elseif IsDisabledControlJustPressed(0, 177) then
                FinishTutorial()
            end
        end
    end)
end)

local function LoadFreemodeModel(gender)
    local requestedModel = joaat(gender == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    local fallbackModel = joaat('mp_m_freemode_01')
    local model = requestedModel

    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print('[rp_characters] Requested freemode model is invalid; using the male fallback model.')
        model = fallbackModel
    end
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print('[rp_characters] No valid freemode model is available; character appearance cannot be applied.')
        return false
    end

    if GetEntityModel(PlayerPedId()) ~= model then
        local previousPed = PlayerPedId()
        local previousCoords = GetEntityCoords(previousPed)
        local previousHeading = GetEntityHeading(previousPed)
        local wasFrozen = IsEntityPositionFrozen(previousPed)

        RequestModel(model)
        local timeout = GetGameTimer() + 10000
        while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
        if not HasModelLoaded(model) then
            print('[rp_characters] Freemode model loading timed out.')
            return false
        end

        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)

        local pedDeadline = GetGameTimer() + 5000
        while GetEntityModel(PlayerPedId()) ~= model and GetGameTimer() < pedDeadline do
            Wait(0)
        end
        if GetEntityModel(PlayerPedId()) ~= model then
            print('[rp_characters] Player model swap did not complete; using the current player model.')
            return false
        end

        -- SetPlayerModel replaces the ped. Restore the creator/spawn transform
        -- and its frozen state so gender changes cannot move or hide the preview.
        local replacementPed = PlayerPedId()
        SetEntityCoordsNoOffset(replacementPed, previousCoords.x, previousCoords.y, previousCoords.z, false, false, false)
        SetEntityHeading(replacementPed, previousHeading)
        FreezeEntityPosition(replacementPed, wasFrozen)
        SetEntityVisible(replacementPed, true, false)
        ResetEntityAlpha(replacementPed)
        SetEntityCollision(replacementPed, true, true)
    end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    -- Reset to GTA's complete freemode base outfit before applying saved data.
    -- This prevents empty or partially-corrupted skin records from leaving a naked ped.
    SetPedDefaultComponentVariation(ped)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    return true
end

local function SetSafeComponent(ped, component, drawable, texture)
    local count = GetNumberOfPedDrawableVariations(ped, component)
    if not count or count < 1 then return end
    drawable = math.max(0, math.min(math.floor(tonumber(drawable) or 0), count - 1))
    local textures = GetNumberOfPedTextureVariations(ped, component, drawable)
    texture = math.max(0, math.min(math.floor(tonumber(texture) or 0), math.max(0, (textures or 1) - 1)))
    SetPedComponentVariation(ped, component, drawable, texture, 0)
end

local function ApplyCharacterAppearance(gender, skin)
    skin = type(skin) == 'table' and skin or {}
    if not LoadFreemodeModel(gender) then
        -- Last-resort visual recovery: keep the current ped visible and restore
        -- its default components rather than applying clothing natives to an invalid model.
        local currentPed = PlayerPedId()
        if currentPed and currentPed ~= 0 and DoesEntityExist(currentPed) then
            SetPedDefaultComponentVariation(currentPed)
            SetEntityVisible(currentPed, true, false)
            ResetEntityAlpha(currentPed)
            SetEntityCollision(currentPed, true, true)
        end
        return false
    end

    local ped = PlayerPedId()

    -- GTA freemode genetic inheritance and facial morphs.
    if type(skin.headBlend) == 'table' then
        local blend = skin.headBlend
        local function blendId(key, fallback)
            local value = tonumber(blend[key])
            if not value or value % 1 ~= 0 then return fallback end
            return math.max(0, math.min(45, value))
        end
        local function blendMix(key, fallback)
            local value = tonumber(blend[key])
            if not value or value ~= value then return fallback end
            return math.max(0.0, math.min(1.0, value))
        end
        SetPedHeadBlendData(ped,
            blendId('shapeFirst', 0), blendId('shapeSecond', 21), blendId('shapeThird', 0),
            blendId('skinFirst', 0), blendId('skinSecond', 21), blendId('skinThird', 0),
            blendMix('shapeMix', 0.5), blendMix('skinMix', 0.5), blendMix('thirdMix', 0.0), false)
        UpdatePedHeadBlendData(ped, true)
    end

    -- Apply all 20 GTA face morph sliders, clamped to the native range.
    if type(skin.faceFeatures) == 'table' then
        for index = 0, 19 do
            local value = tonumber(skin.faceFeatures[tostring(index)] or skin.faceFeatures[index])
            if value and value == value then
                SetPedFaceFeature(ped, index, math.max(-1.0, math.min(1.0, value)))
            end
        end
    end

    -- Hair, eye colour and clothing components from the creator payload.
    local hairStyle = tonumber(skin.hairStyle)
    if hairStyle then SetSafeComponent(ped, 2, hairStyle, 0) end
    local hairColor = math.max(0, math.min(63, math.floor(tonumber(skin.hairColor) or 0)))
    SetPedHairColor(ped, hairColor, hairColor)
    local eyeColor = tonumber(skin.eyeColor)
    if eyeColor then SetPedEyeColor(ped, math.max(0, math.min(31, math.floor(eyeColor)))) end

    if type(skin.components) == 'table' then
        for componentKey, item in pairs(skin.components) do
            local component = tonumber(componentKey)
            if component and component >= 0 and component <= 11 and type(item) == 'table' then
                SetSafeComponent(ped, component, item.drawable, item.texture)
            end
        end
    end

    -- Facial hair and eyebrow overlays.
    if type(skin.overlays) == 'table' then
        for overlayKey, item in pairs(skin.overlays) do
            local overlay = tonumber(overlayKey)
            if overlay and overlay >= 0 and overlay <= 12 and type(item) == 'table' then
                local count = GetPedHeadOverlayNum(overlay) or 0
                local index = math.floor(tonumber(item.index) or 0)
                if count > 0 then index = math.max(0, math.min(index, count - 1)) else index = 0 end
                local opacity = tonumber(item.opacity) or 1.0
                opacity = math.max(0.0, math.min(1.0, opacity))
                SetPedHeadOverlay(ped, overlay, index, opacity)
                local color = math.max(0, math.min(63, math.floor(tonumber(item.color) or hairColor)))
                SetPedHeadOverlayColor(ped, overlay, 1, color, color)
            end
        end
    end

    -- Props use -1 to mean "remove"; otherwise clamp drawable and texture indices.
    if type(skin.props) == 'table' then
        for propKey, item in pairs(skin.props) do
            local prop = tonumber(propKey)
            if prop and prop >= 0 and prop <= 7 and type(item) == 'table' then
                local drawable = math.floor(tonumber(item.drawable) or -1)
                local drawableCount = GetNumberOfPedPropDrawableVariations(ped, prop) or 0
                if drawable < 0 or drawableCount < 1 then
                    ClearPedProp(ped, prop)
                else
                    drawable = math.max(0, math.min(drawable, drawableCount - 1))
                    local texture = math.floor(tonumber(item.texture) or 0)
                    local textureCount = GetNumberOfPedPropTextureVariations(ped, prop, drawable) or 1
                    texture = math.max(0, math.min(texture, math.max(0, textureCount - 1)))
                    SetPedPropIndex(ped, prop, drawable, texture, true)
                end
            end
        end
    end

    -- A malformed or missing skin must never leave the player invisible.
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    return true
end

RegisterNetEvent('rp_characters:client:adminApplySkin', function(gender, skin)
    if gender ~= 'm' and gender ~= 'f' then return end
    if type(skin) ~= 'table' then skin = {} end
    local applied = ApplyCharacterAppearance(gender, skin)
    if not applied then
        print('[rp_characters] Admin skin change could not be fully applied; default appearance was restored.')
    end
end)

local function OpenCreator(maxCharacters)
    characterSessionReady = false
    SetPlayerControl(PlayerId(), false, 0)
    SetNuiFocus(true, true)

    local ped = PlayerPedId()
    local pedDeadline = GetGameTimer() + 5000
    while (not ped or ped == 0 or not DoesEntityExist(ped)) and GetGameTimer() < pedDeadline do
        Wait(0)
        ped = PlayerPedId()
    end
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        print('[rp_characters] Creator preview could not acquire a valid player ped.')
        SetPlayerControl(PlayerId(), true, 0)
        SetNuiFocus(false, false)
        return
    end
    SetEntityCoordsNoOffset(ped, -1042.0, -2745.0, 21.3, false, false, false)
    SetEntityHeading(ped, 330.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)

    -- Apply the initial appearance after placing the ped. The model swap
    -- routine preserves this exact transform when the gender/model changes.
    local previewReady = ApplyCharacterAppearance('m', { hairStyle = 4, hairColor = 0, clothing = 'casual' })
    ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, true)
    end
    if not previewReady then
        print('[rp_characters] Default preview appearance failed; keeping the visible GTA ped.')
    end
    isCreating = true
    SetupCreatorCamera()
    if IsScreenFadedOut() then DoScreenFadeIn(500) end
    SendNUIMessage({ action = 'openRegistration', maxCharacters = maxCharacters or 3 })
end

local function UpdateCreatorCamera()
    if not charCamera then return end
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    -- Keep the camera in front of the ped, centered on the face and upper body.
    local cameraCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 3.25, 0.9)
    SetCamCoord(charCamera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    PointCamAtEntity(charCamera, ped, 0.0, 0.0, 0.9, true)
end

function SetupCreatorCamera()
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, -1042.0, -2745.0, 21.3, false, false, false)
    SetEntityHeading(ped, 330.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)

    -- Load the preview location before creating the scripted camera.
    RequestCollisionAtCoord(-1042.0, -2745.0, 21.3)
    local collisionDeadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionDeadline do
        RequestCollisionAtCoord(-1042.0, -2745.0, 21.3)
        Wait(50)
        ped = PlayerPedId()
    end

    if charCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    charCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not charCamera or charCamera == 0 then
        print('[rp_characters] Creator camera creation failed; falling back to gameplay camera.')
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        return
    end
    UpdateCreatorCamera()
    SetCamFov(charCamera, 38.0)
    SetCamActive(charCamera, true)
    RenderScriptCams(true, true, 500, true, true)
    print(('[rp_characters] Creator preview ready; ped=%s model=%s camera=%s')
        :format(tostring(ped), tostring(GetEntityModel(ped)), tostring(charCamera)))
end

local function CloseCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRegistration' })
    SendNUIMessage({ action = 'closeCharacterSelection' })
    if charCamera then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    FreezeEntityPosition(PlayerPedId(), not characterSessionReady)
    isCreating = false
end

RegisterNUICallback('beginCreation', function(data, cb)
    CloseCharacterUI()
    OpenCreator(3)
    cb({ status = 'ok' })
end)

RegisterNUICallback('saveCharacter', function(data, cb)
    if not isCreating or creationSubmissionPending or type(data) ~= 'table' then
        cb({ status = 'error' })
        return
    end
    creationSubmissionPending = true
    creationSubmissionToken = creationSubmissionToken + 1
    local submissionToken = creationSubmissionToken
    TriggerServerEvent('rp_characters:server:createCharacter', data)
    SetTimeout(20000, function()
        if submissionToken ~= creationSubmissionToken or not creationSubmissionPending then return end
        creationSubmissionPending = false
        SendNUIMessage({
            action = 'creationResult',
            ok = false,
            message = 'Le serveur ne confirme pas la création après 20 secondes. Vérifiez la console FXServer et oxmysql avant de réessayer.'
        })
    end)
    cb({ status = 'submitted' })
end)

RegisterNetEvent('rp_characters:client:creationResult', function(result)
    if type(result) ~= 'table' then
        creationSubmissionPending = false
        creationSubmissionToken = creationSubmissionToken + 1
        SendNUIMessage({
            action = 'creationResult',
            ok = false,
            message = 'Réponse serveur invalide pendant la création du personnage.'
        })
        return
    end

    creationSubmissionPending = false
    creationSubmissionToken = creationSubmissionToken + 1

    if result.ok == true then
        print('[rp_characters] Server confirmed character creation and load.')
        return
    end

    SendNUIMessage({
        action = 'creationResult',
        ok = false,
        message = type(result.message) == 'string' and result.message or 'La création a échoué. Vérifiez les informations puis réessayez.'
    })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    local slot = type(data) == 'table' and tonumber(data.slot) or nil
    if not slot or slot < 1 then
        cb({ status = 'error' })
        return
    end

    -- Close selector immediately so the player is never left on a black NUI layer
    -- while waiting for CreateRPPlayer / spawnPlayer.
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCharacterSelection' })
    SendNUIMessage({ action = 'closeRegistration' })
    if charCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    ClearFocus()
    characterSessionReady = false
    characterBootFailed = false
    creationSubmissionPending = false
    isCreating = false

    selectWatchdogToken = selectWatchdogToken + 1
    local token = selectWatchdogToken

    TriggerServerEvent('rp_characters:server:selectCharacter', slot)
    cb({ status = 'submitted' })

    CreateThread(function()
        local started = GetGameTimer()
        while token == selectWatchdogToken and not characterSessionReady and not characterBootFailed do
            if (GetGameTimer() - started) >= 15000 then
                break
            end
            Wait(250)
        end
        if token ~= selectWatchdogToken or characterSessionReady or characterBootFailed then
            return
        end
        print('[rp_characters] Spawn watchdog: no spawnPlayer within 15s after selectCharacter.')
        ShowCharacterBootError('Le spawn n\'a pas répondu après la sélection. Vérifiez la console serveur (CreateRPPlayer / oxmysql), puis resélectionnez votre personnage avec /relog ou en vous reconnectant.')
        -- Ask core to re-open the account / character selection path.
        TriggerServerEvent('rp_core:server:requestPlayerDataSync')
    end)
end)

RegisterNUICallback('updateSkinPreview', function(data, cb)
    if type(data) == 'table' then
        ApplyCharacterAppearance(data.gender, data.skin)
        UpdateCreatorCamera()
    end
    cb({ status = 'ok' })
end)

RegisterNUICallback('rotateCharacter', function(data, cb)
    local direction = type(data) == 'table' and tonumber(data.direction) or nil
    if direction ~= -1 and direction ~= 1 then
        cb({ status = 'error' })
        return
    end
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) and isCreating then
        SetEntityHeading(ped, (GetEntityHeading(ped) + (direction * 15.0)) % 360.0)
        UpdateCreatorCamera()
    end
    cb({ status = 'ok' })
end)

RegisterNetEvent('rp_characters:client:openMenu', function(maxCharacters)
    characterBootFailed = false
    characterSessionReady = false
    creationSubmissionPending = false
    creationSubmissionToken = creationSubmissionToken + 1
    -- The creator is the first screen for a new account. The loading screen
    -- must be closed here, not only after a character is spawned.
    FinishCharacterBoot()
    OpenCreator(maxCharacters)
end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function(characters, maxCharacters)
    characterBootFailed = false
    characterSessionReady = false
    creationSubmissionPending = false
    creationSubmissionToken = creationSubmissionToken + 1
    -- Keep the player locked, but never hide the world behind the selector.
    -- The previous implementation made the ped fully transparent and did not
    -- create a preview camera, leaving the user with a black screen.
    FinishCharacterBoot()
    characterSessionReady = false
    isCreating = false
    SetPlayerControl(PlayerId(), false, 0)

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        print('[rp_characters] Character selector could not acquire a valid player ped.')
        ShowCharacterBootError('Impossible de préparer l’aperçu du personnage. Réessayez de vous connecter.')
        return
    end

    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, true)

    -- Display a visible freemode preview while the saved-character cards are open.
    -- The real saved skin is applied by the normal server spawn pipeline on selection.
    if not LoadFreemodeModel('m') then
        print('[rp_characters] Character selector preview model could not be loaded; keeping current ped visible.')
    end
    ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, true)
    end

    SetupCreatorCamera()
    if IsScreenFadedOut() then DoScreenFadeIn(700) end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCharacterSelection', characters = characters, maxCharacters = maxCharacters or 3 })
end)

RegisterNetEvent('rp_characters:client:bootError', function(message)
    -- A boot/load failure can also occur after the initial menu has opened.
    -- Do not silently discard it just because the first boot timer has ended.
    ShowCharacterBootError(message)
end)

RegisterNetEvent('rp_characters:client:closeMenu', function()
    CloseCharacterUI()
end)

local SPAWN_TIMER_MODULUS = 4294967296

local function SpawnWaitExpired(startedAt, duration)
    return ((GetGameTimer() % SPAWN_TIMER_MODULUS) - startedAt) % SPAWN_TIMER_MODULUS >= duration
end

local function NormalizeClientSpawn(coords)
    local fallback = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }
    if type(coords) ~= 'table' then return fallback end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    local heading = tonumber(coords.heading)
    local function finite(value)
        return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
    end
    if not finite(x) or not finite(y) or not finite(z)
        or x < -6000 or x > 6000 or y < -6000 or y > 6000
        or z < -500 or z > 2000 then
        return fallback
    end
    if not finite(heading) then heading = fallback.heading end
    return { x = x, y = y, z = z, heading = heading % 360 }
end

RegisterNetEvent('rp_characters:client:spawnPlayer', function(coords, gender, skin)
    -- Run the entire transition in a protected thread. A Lua/native error during
    -- skin application, camera teardown or streaming must never strand the
    -- player in a faded-out, frozen state.
    CreateThread(function()
        print('[rp_characters] Spawn pipeline received from server.')
        creationSubmissionPending = false
        creationSubmissionToken = creationSubmissionToken + 1
        characterBootFailed = false
        characterSessionReady = false
        coords = NormalizeClientSpawn(coords)

        local spawnX, spawnY, spawnZ = coords.x, coords.y, coords.z
        local spawnHeading = coords.heading
        local ped = PlayerPedId()
        local collisionLoaded = false
        local pipelineOk, pipelineError = xpcall(function()
            pcall(SendLoadingScreenMessage, json.encode({
                eventName = 'lssStage',
                stage = 'player',
                status = 'Finalisation de votre personnage...'
            }))

            -- Release every layer belonging to the creator before fading the
            -- world. Do not rely solely on the preceding closeMenu event.
            SetNuiFocus(false, false)
            SendNUIMessage({ action = 'closeRegistration' })
            SendNUIMessage({ action = 'closeCharacterSelection' })
            if charCamera then
                RenderScriptCams(false, true, 0, true, true)
                DestroyCam(charCamera, false)
                charCamera = nil
            else
                RenderScriptCams(false, true, 0, true, true)
            end
            ClearFocus()

            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
            -- Force fade-out but never wait forever (black-screen hang guard).
            DoScreenFadeOut(300)
            local fadeStartedAt = GetGameTimer() % SPAWN_TIMER_MODULUS
            while not IsScreenFadedOut() and not SpawnWaitExpired(fadeStartedAt, 2500) do
                Wait(10)
            end
            if not IsScreenFadedOut() then
                -- Some clients never report faded-out; continue the pipeline anyway.
                print('[rp_characters] Fade-out did not complete in time; continuing spawn.')
            end

            local appearanceApplied = ApplyCharacterAppearance(gender, skin)
            ped = PlayerPedId()
            if not appearanceApplied then
                print('[rp_characters] Appearance fallback was required; applying GTA default components.')
                SetPedDefaultComponentVariation(ped)
            end

            FreezeEntityPosition(ped, true)
            SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false)
            SetEntityHeading(ped, spawnHeading)
            RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
            SetFocusPosAndVel(spawnX, spawnY, spawnZ, 0.0, 0.0, 0.0)

            local collisionStartedAt = GetGameTimer() % SPAWN_TIMER_MODULUS
            while not HasCollisionLoadedAroundEntity(ped)
                and not SpawnWaitExpired(collisionStartedAt, 8000) do
                RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
                Wait(50)
                ped = PlayerPedId()
            end
            collisionLoaded = HasCollisionLoadedAroundEntity(ped)
            if not collisionLoaded then
                print('[rp_characters] Spawn collision streaming timed out; recovering with a visible player.')
            end
        end, debug.traceback)

        -- Stop the startup lock only after the spawn work has reached its
        -- recovery phase. Setting this before the pipeline completes allowed
        -- the startup thread and spawn finalizer to race over player control.
        characterSessionReady = true

        -- Mandatory finalizer: execute each recovery action independently so
        -- one failed native cannot prevent the remaining display/control fixes.
        local function recover(label, callback)
            local ok, err = pcall(callback)
            if not ok then
                print(('[rp_characters] Spawn recovery step "%s" failed: %s'):format(label, tostring(err)))
            end
        end

        ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            recover('position', function()
                SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false)
                SetEntityHeading(ped, spawnHeading)
            end)
            recover('visibility', function()
                SetEntityVisible(ped, true, false)
                ResetEntityAlpha(ped)

                SetEntityCollision(ped, true, true)
                FreezeEntityPosition(ped, false)
            end)
        end
        recover('camera', function()
            if charCamera then
                RenderScriptCams(false, false, 0, true, true)
                DestroyCam(charCamera, false)
                charCamera = nil
            end
            RenderScriptCams(false, false, 0, true, true)
        end)
        recover('focus', ClearFocus)
        recover('nui-focus', function() SetNuiFocus(false, false) end)
        recover('player-control', function() SetPlayerControl(PlayerId(), true, 0) end)
        recover('radar', function() DisplayRadar(true) end)
        recover('loading-screen', function()
            ShutdownLoadingScreen()
            ShutdownLoadingScreenNui()
        end)
        recover('screen-fade', function()
            if IsScreenFadedOut() or IsScreenFadingOut() then
                DoScreenFadeIn(0)
            end
            DoScreenFadeIn(500)
        end)

        -- Some client resources can reapply a fade after the spawn event.
        -- Keep a bounded recovery window and reset camera/timecycle state as well
        -- as the ped, NUI focus and player controls.
        CreateThread(function()
            local recoveredFrames = 0
            for attempt = 1, 30 do
                Wait(500)
                SetNuiFocus(false, false)
                SetNuiFocusKeepInput(false)
                ClearFocus()
                DisplayRadar(true)
                SetPlayerControl(PlayerId(), true, 0)

                if IsScreenFadedOut() or IsScreenFadingOut() then
                    DoScreenFadeIn(0)
                end
                -- These are harmless when no modifier is active and recover
                -- clients left with a black timecycle by another transition.
                ClearTimecycleModifier()
                ClearExtraTimecycleModifier()

                local p = PlayerPedId()
                if p and p ~= 0 and DoesEntityExist(p) then
                    SetEntityVisible(p, true, false)
                    ResetEntityAlpha(p)
                    FreezeEntityPosition(p, false)
                    SetEntityCollision(p, true, true)
                end

                if not IsScreenFadedOut() and not IsScreenFadingOut() then
                    recoveredFrames = recoveredFrames + 1
                    if recoveredFrames >= 4 then break end
                else
                    recoveredFrames = 0
                end
            end
            print(('[rp_characters] Display recovery finished; fadedOut=%s fadingOut=%s.')
                :format(tostring(IsScreenFadedOut()), tostring(IsScreenFadingOut())))
        end)

        Wait(900)
        if not pipelineOk then
            print(('[rp_characters] Spawn pipeline recovered after an error: %s'):format(tostring(pipelineError)))
            TriggerEvent('chat:addMessage', {

                color = { 255, 170, 60 },
                multiline = true,
                args = { 'LOS SANTOS RP', 'Le chargement a rencontré une erreur. Votre affichage a été rétabli ; consultez la console F8.' }
            })
            return
        end

        print(('[rp_characters] Spawn pipeline completed; collisionLoaded=%s position=%.2f,%.2f,%.2f.')
            :format(tostring(collisionLoaded), spawnX, spawnY, spawnZ))
        TriggerServerEvent('rp_characters:server:requestTutorial')
    end)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- Mark the initialization pending before waiting for the network session so an
    -- early rp_core response cannot be overwritten by a later timeout thread.
    characterBootPending = true
    characterSessionReady = false
    SetPlayerControl(PlayerId(), false, 0)
    CreateThread(function()
        -- Re-assert the lock if spawnmanager or a reconnect flow restores player control.
        while not characterSessionReady and not characterBootFailed do
            SetPlayerControl(PlayerId(), false, 0)
            local ped = PlayerPedId()

            if ped and ped ~= 0 and DoesEntityExist(ped) then
                FreezeEntityPosition(ped, true)
            end
            Wait(500)
        end
    end)
    CreateThread(function()
        -- Wait for FiveM's network session before requesting account data.
        local deadline = GetGameTimer() + 30000
        while not NetworkIsSessionStarted() and GetGameTimer() < deadline do
            Wait(250)
        end
        if not NetworkIsSessionStarted() then
            ShowCharacterBootError('La session FiveM ne répond pas. Reconnectez-vous au serveur.')
            return
        end
        -- The creator/selector may already have opened while this thread was
        -- waiting for NetworkIsSessionStarted. Never restart its boot timer.
        if not characterBootPending then return end

        pcall(SendLoadingScreenMessage, json.encode({
            eventName = 'lssStage',
            stage = 'player',
            status = 'Chargement du compte et des personnages...'
        }))
        -- rp_core owns the initialization request and already retries session sync.
        -- A second direct request here would race the core account lookup:

        -- the second request hit the 5s cooldown and falsely timed out after
        -- the first request had already opened the creator.
        print('[rp_characters] Requesting account initialization through rp_core...')
        TriggerServerEvent('rp_core:server:requestPlayerDataSync')

        -- Never leave the loading screen covering the UI indefinitely.
        Wait(20000)
        if characterBootPending then
            ShowCharacterBootError('Le serveur ne répond pas au chargement du compte. Vérifiez oxmysql et la console serveur, puis reconnectez-vous.')
            print('[rp_characters] Character initialization timed out waiting for server response.')
        end
    end)
end)
