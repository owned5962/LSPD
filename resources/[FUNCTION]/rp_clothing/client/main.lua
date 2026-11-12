local isShopOpen = false
local activeShopPosition = nil
local clothingPromptVisible = false
local clothingCamera = nil

local function stopClothingCamera()
    if clothingCamera and DoesCamExist(clothingCamera) then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(clothingCamera, false)
    end
    clothingCamera = nil
end

local function updateClothingCamera()
    if not clothingCamera or not DoesCamExist(clothingCamera) then return end
    local ped = PlayerPedId()
    local cameraCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.8, 0.8)
    SetCamCoord(clothingCamera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    local pedCoords = GetEntityCoords(ped)
    local right = GetEntityRightVector(ped)
    -- Offset the camera's look-at point so the character sits in the left
    -- preview area and is not hidden behind the tablet on the right.
    PointCamAtCoord(clothingCamera,
        pedCoords.x + right.x * 0.55,
        pedCoords.y + right.y * 0.55,
        pedCoords.z + 0.9)
end

local function startClothingCamera()
    stopClothingCamera()
    clothingCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    if not clothingCamera or clothingCamera == 0 then clothingCamera = nil; return end
    SetCamFov(clothingCamera, 42.0)
    updateClothingCamera()
    SetCamActive(clothingCamera, true)
    RenderScriptCams(true, true, 500, true, true)
end

CreateThread(function()
    while true do
        if isShopOpen then
            local ped = PlayerPedId()
            if not activeShopPosition or #(GetEntityCoords(ped) - activeShopPosition) > 1.0 then
                isShopOpen = false
                activeShopPosition = nil
                stopClothingCamera()
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'close' })
                TriggerEvent('rp_core:client:notify', 'Boutique fermée : vous avez quitté la zone.', 'info')
                Wait(250)
            else
                updateClothingCamera()
                Wait(0)
            end
        else
            Wait(250)
        end
    end
end)


AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isShopOpen = false
    stopClothingCamera()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopClothingCamera()
    if clothingPromptVisible then exports['rp_ui']:HideTextUI(); clothingPromptVisible = false end
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
    vector3(123.6, -219.5, 54.6)
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


local clothingCategories = {
    { id = 'tops', label = 'Hauts & vestes', kind = 'component', index = 11 },
    { id = 'undershirts', label = 'T-shirts & sous-hauts', kind = 'component', index = 8 },
    { id = 'arms', label = 'Bras & gants', kind = 'component', index = 3 },
    { id = 'pants', label = 'Pantalons', kind = 'component', index = 4 },
    { id = 'shoes', label = 'Chaussures', kind = 'component', index = 6 },
    { id = 'bags', label = 'Sacs', kind = 'component', index = 5 },
    { id = 'accessories', label = 'Accessoires', kind = 'component', index = 7 },
    { id = 'decals', label = 'Motifs & écussons', kind = 'component', index = 10 },
    { id = 'vests', label = 'Gilets & protections', kind = 'component', index = 9 },
    { id = 'hats', label = 'Casquettes & chapeaux', kind = 'prop', index = 0 },
    { id = 'glasses', label = 'Lunettes', kind = 'prop', index = 1 },
    { id = 'ears', label = 'Bijoux & boucles d’oreilles', kind = 'prop', index = 2 },
    { id = 'watches', label = 'Montres', kind = 'prop', index = 6 },
    { id = 'bracelets', label = 'Bracelets', kind = 'prop', index = 7 }
}

local function GetClothingCatalog()
    local ped = PlayerPedId()
    local catalog = {}
    for _, category in ipairs(clothingCategories) do
        local count, drawable, texture
        if category.kind == 'component' then
            count = GetNumberOfPedDrawableVariations(ped, category.index) or 0
            drawable = GetPedDrawableVariation(ped, category.index)
            texture = GetPedTextureVariation(ped, category.index)
        else
            count = (GetNumberOfPedPropDrawableVariations(ped, category.index) or 0) + 1
            drawable = GetPedPropIndex(ped, category.index) + 1
            texture = GetPedPropTextureIndex(ped, category.index)
        end
        texture = math.max(0, tonumber(texture) or 0)
        local nativeDrawable = category.kind == 'prop' and drawable - 1 or drawable
        local textureCount = 1
        if nativeDrawable >= 0 then
            textureCount = category.kind == 'component'
                and (GetNumberOfPedTextureVariations(ped, category.index, nativeDrawable) or 1)
                or (GetNumberOfPedPropTextureVariations(ped, category.index, nativeDrawable) or 1)
        end
        catalog[#catalog + 1] = {
            id = category.id, label = category.label, kind = category.kind, index = category.index,
            count = math.max(1, count), drawable = drawable, texture = texture,
            textureCount = math.max(1, textureCount)
        }
    end
    return catalog
end

local function ApplyCatalogVariation(data)
    if type(data) ~= 'table' or type(data.kind) ~= 'string' then return nil end
    local index, drawable, texture = tonumber(data.index), tonumber(data.drawable), tonumber(data.texture) or 0
    if not index or not drawable or index % 1 ~= 0 or drawable % 1 ~= 0 or texture % 1 ~= 0 then return nil end
    local ped = PlayerPedId()
    local count, textureCount
    if data.kind == 'component' and index >= 0 and index <= 11 then
        count = GetNumberOfPedDrawableVariations(ped, index) or 0
        if count < 1 or drawable < 0 or drawable >= count then return nil end
        textureCount = GetNumberOfPedTextureVariations(ped, index, drawable) or 1
        texture = math.max(0, math.min(texture, math.max(0, textureCount - 1)))
        SetPedComponentVariation(ped, index, drawable, texture, 0)
    elseif data.kind == 'prop' and index >= 0 and index <= 7 then
        count = (GetNumberOfPedPropDrawableVariations(ped, index) or 0) + 1
        if drawable < 0 or drawable >= count then return nil end
        if drawable == 0 then
            ClearPedProp(ped, index)
            textureCount = 1
            texture = 0
        else
            local nativeDrawable = drawable - 1
            textureCount = GetNumberOfPedPropTextureVariations(ped, index, nativeDrawable) or 1
            texture = math.max(0, math.min(texture, math.max(0, textureCount - 1)))
            SetPedPropIndex(ped, index, nativeDrawable, texture, true)
        end
    else
        return nil
    end
    return { texture = texture, textureCount = math.max(1, textureCount or 1) }
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
        local sleep = 700
        local nearShop = false
        if not isShopOpen and not IsPauseMenuActive() then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, pos in ipairs(clothingShops) do
                local dist = #(playerCoords - pos)
                if dist < 15.0 then
                    sleep = 100
                    DrawMarker(20, pos.x, pos.y, pos.z, 0, 0, 0, 0, 0, 0,
                        0.6, 0.6, 0.6, 56, 189, 248, 150, false, true, 2, false, nil, nil, false)
                end
                if dist <= 1.0 then
                    nearShop = true
                    sleep = 0
                    if IsControlJustReleased(0, 38) then
                        isShopOpen = true
                        activeShopPosition = pos
                        if clothingPromptVisible then
                            exports['rp_ui']:HideTextUI()
                            clothingPromptVisible = false
                        end
                        SetNuiFocus(true, true)
                        startClothingCamera()
                        SendNUIMessage({ action = 'open', catalog = GetClothingCatalog() })
                        break
                    end
                end
            end
        end

        if nearShop and not isShopOpen and not clothingPromptVisible then
            exports['rp_ui']:ShowTextUI('[E] Ouvrir la boutique de vêtements')
            clothingPromptVisible = true
        elseif (not nearShop or isShopOpen or IsPauseMenuActive()) and clothingPromptVisible then
            exports['rp_ui']:HideTextUI()
            clothingPromptVisible = false
        end
        Wait(sleep)
    end
end)

RegisterNUICallback('rotatePlayer', function(data, cb)
    if not isShopOpen then cb({ ok = false }); return end
    local direction = type(data) == 'table' and tonumber(data.direction) or nil
    if direction ~= -1 and direction ~= 1 then cb({ ok = false }); return end
    local ped = PlayerPedId()
    SetEntityHeading(ped, (GetEntityHeading(ped) + (direction * 12.0)) % 360.0)
    cb({ ok = true })
end)

RegisterNUICallback('previewVariation', function(data, cb)
    local result = ApplyCatalogVariation(data)
    cb(result or { status = 'invalid_variation' })
end)

RegisterNUICallback('applyPreset', function(data, cb)
    local ok = type(data) == 'table' and ApplyPreset(data.outfit)
    cb({ status = ok and 'ok' or 'invalid_preset' })
end)

RegisterNUICallback('close', function(data, cb)
    isShopOpen = false
    activeShopPosition = nil
    stopClothingCamera()
    if clothingPromptVisible then exports['rp_ui']:HideTextUI(); clothingPromptVisible = false end
    SetNuiFocus(false, false)
    exports['rp_ui']:HideTextUI()
    SendNUIMessage({ action = 'close' })
    cb({ status = 'ok' })
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    if type(data) ~= 'table' then cb({ status = 'error' }); return end
    TriggerServerEvent('rp_clothing:saveOutfit', data.name, CaptureAppearance())
    isShopOpen = false
    activeShopPosition = nil
    stopClothingCamera()
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
