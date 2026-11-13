local isCreating = false
local charCamera = nil
local characterBootPending = false
local characterSessionReady = false

local function FinishCharacterBoot()
    characterBootPending = false
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)
end

local function ShowCharacterBootError(message)
    FinishCharacterBoot()
    TriggerEvent('chat:addMessage', {
        color = { 255, 90, 90 },
        multiline = true,
        args = { 'LOS SANTOS RP', message or 'Le chargement du personnage a échoué. Consultez la console serveur.' }
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
        -- Force GTA to refresh the blended face after parent and mix sliders change.
        UpdatePedHeadBlendData(ped, true)
    end

    if type(skin.faceFeatures) == 'table' then
        for feature = 0, 19 do
            local value = tonumber(skin.faceFeatures[tostring(feature)] or skin.faceFeatures[feature]) or 0.0
            if value == value then SetPedFaceFeature(ped, feature, math.max(-1.0, math.min(1.0, value))) end
        end
    end
    if type(skin.overlays) == 'table' then
        for overlay = 0, 12 do
            local item = skin.overlays[tostring(overlay)] or skin.overlays[overlay]
            if type(item) == 'table' then
                local index = math.max(0, math.min(255, math.floor(tonumber(item.index) or 0)))
                local opacity = tonumber(item.opacity) or 1.0
                SetPedHeadOverlay(ped, overlay, index, math.max(0.0, math.min(1.0, opacity)))
                local colorType = (overlay == 1 or overlay == 2 or overlay == 10) and 1 or 0
                local color = math.max(0, math.min(63, math.floor(tonumber(item.color) or 0)))
                local second = math.max(0, math.min(63, math.floor(tonumber(item.secondColor) or color)))
                SetPedHeadOverlayColor(ped, overlay, colorType, color, second)
            end
        end
    end
    local eyeColor = tonumber(skin.eyeColor) or 0
    SetPedEyeColor(ped, math.max(0, math.min(31, math.floor(eyeColor))))

    local hairStyle = tonumber(skin.hairStyle) or 0
    local hairCount = GetNumberOfPedDrawableVariations(ped, 2)
    if hairCount and hairCount > 0 then
        hairStyle = math.max(0, math.min(math.floor(hairStyle), hairCount - 1))
        SetPedComponentVariation(ped, 2, hairStyle, 0, 0)
    end
    local hairColor = math.max(0, math.min(math.floor(tonumber(skin.hairColor) or 0), 63))
    SetPedHairColor(ped, hairColor, hairColor)

    local outfits = {
        casual = { pants = 0, shoes = 1, undershirt = 15, top = 15 },
        business = { pants = 10, shoes = 10, undershirt = 10, top = 10 },
        worker = { pants = 36, shoes = 12, undershirt = 59, top = 56 },
        sport = { pants = 5, shoes = 3, undershirt = 15, top = 15 }
    }
    local outfit = outfits[skin.clothing] or outfits.casual
    local safeDefaults = {
        [3] = { 0, 0 }, [4] = { outfit.pants, 0 }, [5] = { 0, 0 },
        [6] = { outfit.shoes, 0 }, [7] = { 0, 0 }, [8] = { outfit.undershirt, 0 },
        [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { outfit.top, 0 }
    }
    -- Even a partially saved outfit must never leave a component missing:
    -- validate every saved drawable/texture and fill absent clothing slots.
    for component = 0, 11 do
        local saved = type(skin.components) == 'table'
            and (skin.components[tostring(component)] or skin.components[component]) or nil
        if type(saved) == 'table' then
            SetSafeComponent(ped, component, saved.drawable, saved.texture)
        elseif safeDefaults[component] then
            SetSafeComponent(ped, component, safeDefaults[component][1], safeDefaults[component][2])
        end
    end

    -- Props are optional. Invalid or missing saved props are cleared safely.
    for prop = 0, 7 do
        local saved = type(skin.props) == 'table'
            and (skin.props[tostring(prop)] or skin.props[prop]) or nil
        if type(saved) == 'table' then
            local drawable = tonumber(saved.drawable) or -1
            local texture = tonumber(saved.texture) or 0
            local propCount = GetNumberOfPedPropDrawableVariations(ped, prop) or 0
            if drawable < 0 or drawable >= propCount then
                ClearPedProp(ped, prop)
            else
                local textureCount = GetNumberOfPedPropTextureVariations(ped, prop, drawable) or 1
                texture = math.max(0, math.min(math.floor(texture), math.max(0, textureCount - 1)))
                SetPedPropIndex(ped, prop, drawable, texture, true)
            end
        else
            ClearPedProp(ped, prop)
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
    SetPlayerControl(PlayerId(), false, 0)
    SetNuiFocus(true, true)
    ApplyCharacterAppearance('m', { hairStyle = 4, hairColor = 0, clothing = 'casual' })
    SendNUIMessage({ action = 'openRegistration', maxCharacters = maxCharacters or 3 })
    isCreating = true
    SetupCreatorCamera()
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
    SetEntityCoords(ped, -1042.0, -2745.0, 21.3, false, false, false, true)
    SetEntityHeading(ped, 330.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    if charCamera then
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    charCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    UpdateCreatorCamera()
    SetCamFov(charCamera, 45.0)
    SetCamActive(charCamera, true)
    RenderScriptCams(true, true, 500, true, true)
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
    TriggerServerEvent('rp_characters:server:createCharacter', data)
    cb({ status = 'submitted' })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('rp_characters:server:selectCharacter', data.slot)
    cb({ status = 'submitted' })
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
    -- The creator is the first screen for a new account. The loading screen
    -- must be closed here, not only after a character is spawned.
    FinishCharacterBoot()
    OpenCreator(maxCharacters)
end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function(characters, maxCharacters)
    -- Keep the default spawn unusable until the player explicitly selects a saved character.
    FinishCharacterBoot()
    characterSessionReady = false
    SetPlayerControl(PlayerId(), false, 0)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCharacterSelection', characters = characters, maxCharacters = maxCharacters or 3 })
end)

RegisterNetEvent('rp_characters:client:resumeLoadedCharacter', function()
    characterSessionReady = true
    FinishCharacterBoot()
    SetPlayerControl(PlayerId(), true, 0)
    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
    end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(250)
end)

RegisterNetEvent('rp_characters:client:bootError', function(message)
    if not characterBootPending then return end
    ShowCharacterBootError(message)
end)

RegisterNetEvent('rp_characters:client:closeMenu', function()
    CloseCharacterUI()
end)

RegisterNetEvent('rp_characters:client:spawnPlayer', function(coords, gender, skin)
    pcall(SendLoadingScreenMessage, json.encode({
        eventName = 'lssStage',
        stage = 'player',
        status = 'Finalisation de votre personnage...'
    }))
    characterSessionReady = true
    FinishCharacterBoot()
    coords = type(coords) == 'table' and coords or { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }

    DoScreenFadeOut(500)
    -- Never leave the client thread blocked forever if the fade native fails.
    local fadeDeadline = GetGameTimer() + 5000
    while not IsScreenFadedOut() and GetGameTimer() < fadeDeadline do
        Wait(10)
    end
    if not IsScreenFadedOut() then
        print('[rp_characters] Screen fade-out timed out; continuing character spawn.')
    end

    local appearanceApplied = ApplyCharacterAppearance(gender, skin)
    local ped = PlayerPedId()
    if not appearanceApplied then
        print('[rp_characters] Appearance fallback was required; applying GTA default components.')
        SetPedDefaultComponentVariation(ped)
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
    end
    local spawnX = tonumber(coords.x) or -1037.7
    local spawnY = tonumber(coords.y) or -2737.8
    local spawnZ = tonumber(coords.z) or 20.1
    RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
    SetFocusPosAndVel(spawnX, spawnY, spawnZ, 0.0, 0.0, 0.0)
    local collisionDeadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionDeadline do
        RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
        Wait(50)
    end
    SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false)
    SetEntityHeading(ped, tonumber(coords.heading) or 330.0)
    ClearFocus()
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetPlayerControl(PlayerId(), true, 0)

    -- Close both loading-screen layers after the character has been placed.
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    Wait(500)
    DoScreenFadeIn(1000)
    Wait(1500)
    TriggerServerEvent('rp_characters:server:requestTutorial')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    characterSessionReady = false
    SetPlayerControl(PlayerId(), false, 0)
    CreateThread(function()
        -- Re-assert the lock if spawnmanager or a reconnect flow restores player control.
        while not characterSessionReady do
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

        Wait(1000)
        characterBootPending = true
        pcall(SendLoadingScreenMessage, json.encode({
            eventName = 'lssStage',
            stage = 'player',
            status = 'Chargement du compte et des personnages...'
        }))
        print('[rp_characters] Requesting account and character data...')
        TriggerServerEvent('rp_characters:server:checkPlayer')

        -- Never leave the loading screen covering the UI indefinitely.
        Wait(20000)
        if characterBootPending then
            ShowCharacterBootError('Le serveur ne répond pas au chargement du compte. Vérifiez oxmysql et la console serveur, puis reconnectez-vous.')
            print('[rp_characters] Character boot timed out waiting for server response.')
        end
    end)
end)
