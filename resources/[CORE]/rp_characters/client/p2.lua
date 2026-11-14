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
        -- Force GTA to refresh the blended face after parent and mix sliders change.
        UpdatePedHeadBlendData(ped, true)
    end

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
    TriggerServerEvent('rp_characters:server:createCharacter', data)
    cb({ status = 'submitted' })
end)

RegisterNetEvent('rp_characters:client:creationResult', function(result)
    if type(result) ~= 'table' or result.ok == true then return end
    creationSubmissionPending = false
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
    isCreating = false

    selectWatchdogToken = selectWatchdogToken + 1
    local token = selectWatchdogToken

    TriggerServerEvent('rp_characters:server:selectCharacter', slot)
    cb({ status = 'submitted' })

    CreateThread(function()
        local started = GetGameTimer()
        while token == selectWatchdogToken and not characterSessionReady do
            if (GetGameTimer() - started) >= 15000 then
                break
            end
            Wait(250)
        end
        if token ~= selectWatchdogToken or characterSessionReady then
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
    creationSubmissionPending = false
    -- The creator is the first screen for a new account. The loading screen
    -- must be closed here, not only after a character is spawned.
    FinishCharacterBoot()
    OpenCreator(maxCharacters)
end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function(characters, maxCharacters)
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
        characterSessionReady = true
