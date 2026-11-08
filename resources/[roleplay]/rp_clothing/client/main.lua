local isShopOpen = false
local clothingShops = {
    vector3(72.3, -1399.1, 29.4),
    vector3(-703.8, -152.3, 37.4),
    vector3(-163.2, -303.6, 39.7),
    vector3(425.6, -806.2, 29.5)
}

local presets = {
    civil = { [3] = {0, 0}, [4] = {0, 0}, [6] = {1, 0}, [8] = {15, 0}, [11] = {15, 0} },
    suit = { [3] = {0, 0}, [4] = {10, 0}, [6] = {10, 0}, [8] = {10, 0}, [11] = {10, 0} },
    sport = { [3] = {0, 0}, [4] = {5, 0}, [6] = {3, 0}, [8] = {15, 0}, [11] = {15, 0} },
    work = { [3] = {0, 0}, [4] = {36, 0}, [6] = {12, 0}, [8] = {59, 0}, [11] = {56, 0} }
}

local function SetSafeComponent(ped, component, drawable, texture)
    local count = GetNumberOfPedDrawableVariations(ped, component)
    if not count or count < 1 then return end
    drawable = math.max(0, math.min(drawable, count - 1))
    local textureCount = GetNumberOfPedTextureVariations(ped, component, drawable)
    texture = math.max(0, math.min(texture, math.max(0, (textureCount or 1) - 1)))
    SetPedComponentVariation(ped, component, drawable, texture, 0)
end

local function ApplyPreset(name)
    local preset = presets[name]
    if not preset then return false end
    local ped = PlayerPedId()
    for component, variation in pairs(preset) do
        SetSafeComponent(ped, component, variation[1], variation[2])
    end
    return true
end

local function CaptureAppearance()
    local ped = PlayerPedId()
    local appearance = { components = {}, props = {} }
    for component = 0, 11 do
        appearance.components[tostring(component)] = {
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component)
        }
    end
    for prop = 0, 7 do
        appearance.props[tostring(prop)] = {
            drawable = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop)
        }
    end
    appearance.hairStyle = GetPedDrawableVariation(ped, 2)
    local hairColor, highlightColor = GetPedHairColor(ped)
    appearance.hairColor = hairColor or 0
    return appearance
end

CreateThread(function()
    for _, pos in ipairs(clothingShops) do
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, 73)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 47)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Magasin de vêtements')
        EndTextCommandSetBlipName(blip)
    end

    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, pos in ipairs(clothingShops) do
            local dist = #(playerCoords - pos)
            if dist < 15.0 then
                sleep = 0
                DrawMarker(20, pos.x, pos.y, pos.z, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 0.6, 56, 189, 248, 150, false, true, 2, false, nil, nil, false)
                if dist < 1.8 then
                    exports['rp_ui']:ShowTextUI('[E] Ouvrir la boutique de vêtements')
                    if IsControlJustPressed(0, 38) then
                        isShopOpen = true
                        SetNuiFocus(true, true)
                        SendNUIMessage({ action = 'open' })
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNUICallback('applyPreset', function(data, cb)
    local ok = type(data) == 'table' and ApplyPreset(data.outfit)
    cb({ status = ok and 'ok' or 'invalid_preset' })
end)

RegisterNUICallback('close', function(data, cb)
    isShopOpen = false
    SetNuiFocus(false, false)
    exports['rp_ui']:HideTextUI()
    SendNUIMessage({ action = 'close' })
    cb({ status = 'ok' })
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    if type(data) ~= 'table' then cb({ status = 'error' }); return end
    TriggerServerEvent('rp_clothing:saveOutfit', data.name, CaptureAppearance())
    isShopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb({ status = 'submitted' })
end)
