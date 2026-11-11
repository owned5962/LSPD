local isShopOpen = false

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isShopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
local clothingShops = {
    vector3(72.3, -1399.1, 29.4),
    vector3(-703.8, -152.3, 37.4),
    vector3(-163.2, -303.6, 39.7),
    vector3(425.6, -806.2, 29.5),
    vector3(-1193.4, -768.1, 17.3),
    vector3(-3169.6, 1044.2, 20.9),
    vector3(1693.5, 4823.1, 42.1),
    vector3(618.2, 2759.3, 42.1),
    vector3(4.3, 6512.8, 31.9),
    vector3(1695.3, 3757.7, 34.7)
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


RegisterNUICallback('requestOutfits', function(data, cb)
    TriggerServerEvent('rp_clothing:requestOutfits')
    cb({ status = 'requested' })
end)

RegisterNUICallback('applySavedOutfit', function(data, cb)
    local outfitId = type(data) == 'table' and tonumber(data.id) or nil
    if not outfitId or outfitId % 1 ~= 0 or outfitId < 1 then
        cb({ status = 'invalid_id' })
        return
    end
    TriggerServerEvent('rp_clothing:applySavedOutfit', outfitId)
    cb({ status = 'submitted' })
end)

RegisterNetEvent('rp_clothing:receiveOutfits', function(outfits)
    SendNUIMessage({ action = 'outfits', outfits = type(outfits) == 'table' and outfits or {} })
end)

RegisterNetEvent('rp_clothing:applyAppearance', function(appearance)
    if type(appearance) ~= 'table' or type(appearance.components) ~= 'table' or type(appearance.props) ~= 'table' then return end
    local ped = PlayerPedId()
    for component = 0, 11 do
        local item = appearance.components[tostring(component)]
        if type(item) == 'table' then SetSafeComponent(ped, component, tonumber(item.drawable) or 0, tonumber(item.texture) or 0) end
    end
    for prop = 0, 7 do
        local item = appearance.props[tostring(prop)]
        if type(item) == 'table' then
            local drawable = tonumber(item.drawable) or -1
            if drawable < 0 then
                ClearPedProp(ped, prop)
            else
                local count = GetNumberOfPedPropDrawableVariations(ped, prop)
                if count and drawable < count then
                    local textures = GetNumberOfPedPropTextureVariations(ped, prop, drawable)
                    local texture = math.max(0, math.min(tonumber(item.texture) or 0, math.max(0, (textures or 1) - 1)))
                    SetPedPropIndex(ped, prop, drawable, texture, true)
                end
            end
        end
    end
    SetPedHairColor(ped, math.max(0, math.min(63, tonumber(appearance.hairColor) or 0)), 0)
end)
