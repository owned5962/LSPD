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
