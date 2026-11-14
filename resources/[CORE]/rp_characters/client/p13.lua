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
