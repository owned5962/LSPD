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
