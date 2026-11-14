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
    creationSubmissionPending = false
    -- The creator is the first screen for a new account. The loading screen
    -- must be closed here, not only after a character is spawned.
    FinishCharacterBoot()
    OpenCreator(maxCharacters)
