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
