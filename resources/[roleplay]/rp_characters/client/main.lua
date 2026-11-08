local isCreating = false
local charCamera = nil

local function LoadFreemodeModel(gender)
    local model = joaat(gender == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    if not IsModelInCdimage(model) or not IsModelValid(model) then return false end
    if GetEntityModel(PlayerPedId()) == model then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then return false end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    SetPedDefaultComponentVariation(PlayerPedId())
    return true
end

local function SetSafeComponent(ped, component, drawable, texture)
    local count = GetNumberOfPedDrawableVariations(ped, component)
    if not count or count < 1 then return end
    drawable = math.max(0, math.min(math.floor(tonumber(drawable) or 0), count - 1))
    local textures = GetNumberOfPedTextureVariations(ped, component, drawable)
    texture = math.max(0, math.min(math.floor(tonumber(texture) or 0), math.max(0, (textures or 1) - 1)))
    SetPedComponentVariation(ped, component, drawable, texture, 0)
end

local function ApplyCharacterAppearance(gender, skin)
    skin = type(skin) == 'table' and skin or {}
    LoadFreemodeModel(gender)
    local ped = PlayerPedId()
    local hairStyle = tonumber(skin.hairStyle) or 0
    local hairCount = GetNumberOfPedDrawableVariations(ped, 2)
    if hairCount and hairCount > 0 then
        hairStyle = math.max(0, math.min(math.floor(hairStyle), hairCount - 1))
        SetPedComponentVariation(ped, 2, hairStyle, 0, 0)
    end
    local hairColor = math.max(0, math.min(math.floor(tonumber(skin.hairColor) or 0), 63))
    SetPedHairColor(ped, hairColor, hairColor)

    local outfits = {
        casual = { pants = 0, shoes = 1, undershirt = 15, top = 15 },
        business = { pants = 10, shoes = 10, undershirt = 10, top = 10 },
        worker = { pants = 36, shoes = 12, undershirt = 59, top = 56 },
        sport = { pants = 5, shoes = 3, undershirt = 15, top = 15 }
    }
    if type(skin.components) == 'table' then
        for component = 0, 11 do
            local saved = skin.components[tostring(component)] or skin.components[component]
            if type(saved) == 'table' then
                SetSafeComponent(ped, component, saved.drawable, saved.texture)
            end
        end
    else
        local outfit = outfits[skin.clothing] or outfits.casual
        SetSafeComponent(ped, 4, outfit.pants, 0)
        SetSafeComponent(ped, 6, outfit.shoes, 0)
        SetSafeComponent(ped, 8, outfit.undershirt, 0)
        SetSafeComponent(ped, 11, outfit.top, 0)
        SetSafeComponent(ped, 3, 0, 0)
    end

    if type(skin.props) == 'table' then
        for prop = 0, 7 do
            local saved = skin.props[tostring(prop)] or skin.props[prop]
            if type(saved) == 'table' then
                local drawable = tonumber(saved.drawable) or -1
                local texture = tonumber(saved.texture) or 0
                if drawable < 0 then
                    ClearPedProp(ped, prop)
                else
                    local propCount = GetNumberOfPedPropDrawableVariations(ped, prop)
                    if propCount and propCount > 0 then
                        drawable = math.min(drawable, propCount - 1)
                        local textureCount = GetNumberOfPedPropTextureVariations(ped, prop, drawable)
                        texture = math.max(0, math.min(texture, math.max(0, (textureCount or 1) - 1)))
                        SetPedPropIndex(ped, prop, drawable, texture, true)
                    end
                end
            end
        end
    end
end

local function OpenCreator(maxCharacters)
    SetNuiFocus(true, true)
    ApplyCharacterAppearance('m', { hairStyle = 4, hairColor = 0, clothing = 'casual' })
    SendNUIMessage({ action = 'openRegistration', maxCharacters = maxCharacters or 3 })
    isCreating = true
    SetupCreatorCamera()
end

function SetupCreatorCamera()
    local ped = PlayerPedId()
    SetEntityCoords(ped, -1042.0, -2745.0, 21.3, false, false, false, true)
    SetEntityHeading(ped, 330.0)
    FreezeEntityPosition(ped, true)
    charCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(charCamera, -1040.8, -2743.0, 21.6)
    PointCamAtEntity(charCamera, ped, 0.0, 0.0, 0.2, true)
    SetCamActive(charCamera, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function CloseCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRegistration' })
    SendNUIMessage({ action = 'closeCharacterSelection' })
    if charCamera then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    FreezeEntityPosition(PlayerPedId(), false)
    isCreating = false
end

RegisterNUICallback('beginCreation', function(data, cb)
    CloseCharacterUI()
    OpenCreator(3)
    cb({ status = 'ok' })
end)

RegisterNUICallback('saveCharacter', function(data, cb)
    TriggerServerEvent('rp_characters:server:createCharacter', data)
    cb({ status = 'submitted' })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('rp_characters:server:selectCharacter', data.slot)
    cb({ status = 'submitted' })
end)

RegisterNUICallback('updateSkinPreview', function(data, cb)
    if type(data) == 'table' then ApplyCharacterAppearance(data.gender, data.skin) end
    cb({ status = 'ok' })
end)

RegisterNetEvent('rp_characters:client:openMenu', function(maxCharacters)
    OpenCreator(maxCharacters)
end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function(characters, maxCharacters)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCharacterSelection', characters = characters, maxCharacters = maxCharacters or 3 })
end)

RegisterNetEvent('rp_characters:client:closeMenu', function()
    CloseCharacterUI()
end)

RegisterNetEvent('rp_characters:client:spawnPlayer', function(coords, gender, skin)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    ApplyCharacterAppearance(gender, skin)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.heading or 0.0)
    FreezeEntityPosition(ped, false)
    Wait(500)
    DoScreenFadeIn(1000)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    TriggerServerEvent('rp_characters:server:checkPlayer')
end)
