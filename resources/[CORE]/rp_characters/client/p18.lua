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
