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

