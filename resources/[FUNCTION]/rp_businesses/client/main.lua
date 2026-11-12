local createdBlips = {}
local pendingATMLocations = {}
local locationsLoaded = false
local ATMObjectModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }

local function addLocationBlip(location)
    if location.blip_enabled == false or tonumber(location.blip_enabled) == 0 then return end
    local blip = AddBlipForCoord(location.x, location.y, location.z)
    SetBlipSprite(blip, tonumber(location.blip_sprite) or 1)
    SetBlipDisplay(blip, tonumber(location.blip_display) or 4)
    SetBlipScale(blip, tonumber(location.blip_scale) or 0.7)
    SetBlipColour(blip, tonumber(location.blip_colour) or 0)
    SetBlipAsShortRange(blip, location.short_range == true or tonumber(location.short_range) == 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(location.name or 'Lieu')
    EndTextCommandSetBlipName(blip)
    createdBlips[#createdBlips + 1] = blip
end

local function requestLocations()
    TriggerServerEvent('rp_businesses:server:requestLocations')
end

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    for _, blip in ipairs(createdBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    createdBlips = {}
    pendingATMLocations = {}
    for _, location in ipairs(locations) do
        if location.location_type == 'atm' then
            pendingATMLocations[#pendingATMLocations + 1] = {
                x = tonumber(location.x), y = tonumber(location.y), z = tonumber(location.z),
                name = location.name or 'Distributeur automatique',
                blip_sprite = location.blip_sprite, blip_display = location.blip_display,
                blip_scale = location.blip_scale, blip_colour = location.blip_colour,
                blip_enabled = location.blip_enabled, short_range = location.short_range,
                verified = false
            }
        else
            addLocationBlip(location)
        end
    end
    locationsLoaded = #locations > 0
    if not locationsLoaded then
        SetTimeout(5000, requestLocations)
    end
end)

CreateThread(function()
    Wait(1500)
    requestLocations()
end)


-- ATM map markers are only created after a real GTA ATM prop is found at the
-- configured location. This prevents stale or misplaced database coordinates
-- from advertising an ATM where no machine exists.
CreateThread(function()
    while true do
        local waitTime = 1800
        if #pendingATMLocations > 0 and not IsPauseMenuActive() then
            local playerCoords = GetEntityCoords(PlayerPedId())
            for _, location in ipairs(pendingATMLocations) do
                if not location.verified and location.x and location.y and location.z then
                    local point = vector3(location.x, location.y, location.z)
                    if #(playerCoords - point) <= 65.0 then
                        waitTime = 250
                        for _, model in ipairs(ATMObjectModels) do
                            local object = GetClosestObjectOfType(
                                location.x, location.y, location.z, 7.0, joaat(model), false, false, false
                            )
                            if object and object ~= 0 and DoesEntityExist(object) then
                                local objectCoords = GetEntityCoords(object)
                                if #(objectCoords - point) <= 7.0 then
                                    addLocationBlip({
                                        x = objectCoords.x, y = objectCoords.y, z = objectCoords.z,
                                        name = location.name,
                                        blip_enabled = location.blip_enabled,
                                        blip_sprite = location.blip_sprite,
                                        blip_display = location.blip_display,
                                        blip_scale = location.blip_scale,
                                        blip_colour = location.blip_colour,
                                        short_range = location.short_range
                                    })
                                    location.verified = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(waitTime)
    end
end)


RegisterNetEvent('rp_core:client:setPlayerData', function()
    if not locationsLoaded then requestLocations() end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(createdBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)


-- Ammu-Nation: ouverture de la tablette d'achat au clavier E.
local ammunationLocations = {}
local ammunationPromptVisible = false
local ammunationTabletOpen = false

local function closeAmmunationTablet()
    if not ammunationTabletOpen then return end
    ammunationTabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeAmmunation' })
end

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    ammunationLocations = {}
    for _, location in ipairs(locations) do
        if location.location_type == 'shop' and location.shop_style == 'ammunation' then
            ammunationLocations[#ammunationLocations + 1] = vector3(
                tonumber(location.x) or 0.0,
                tonumber(location.y) or 0.0,
                tonumber(location.z) or 0.0
            )
        end
    end
end)

RegisterNetEvent('rp_businesses:client:openAmmunation', function(cash)
    if ammunationPromptVisible then
        exports['rp_ui']:HideTextUI()
        ammunationPromptVisible = false
    end
    ammunationTabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAmmunation',
        cash = tonumber(cash) or 0,
        price = 500
    })
end)

RegisterNetEvent('rp_businesses:client:purchaseResult', function(result)
    if type(result) ~= 'table' then return end
    SendNUIMessage({
        action = 'purchaseResult',
        success = result.success == true,
        message = tostring(result.message or ''),
        cash = tonumber(result.cash) or 0
    })
end)

RegisterNetEvent('rp_businesses:client:weaponPurchased', function()
    local ped = PlayerPedId()
    local weaponHash = joaat('WEAPON_PISTOL')
    GiveWeaponToPed(ped, weaponHash, 60, false, true)
    SetPedAmmo(ped, weaponHash, math.max(GetAmmoInPedWeapon(ped, weaponHash), 60))
end)

RegisterNUICallback('closeAmmunation', function(_, cb)
    closeAmmunationTablet()
    cb({ ok = true })
end)

RegisterNUICallback('buyAmmunationPistol', function(_, cb)
    TriggerServerEvent('rp_businesses:server:buyPistol')
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        local sleep = 650
        if ammunationTabletOpen then
            sleep = 250
        elseif #ammunationLocations > 0 and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local nearestDistance = 999.0
            for _, shopCoords in ipairs(ammunationLocations) do
                local distance = #(coords - shopCoords)
                if distance < nearestDistance then nearestDistance = distance end
            end

            if nearestDistance <= 1.8 then
                sleep = 0
                if not ammunationPromptVisible then
                    exports['rp_ui']:ShowTextUI('[E] Ouvrir la tablette Ammu-Nation')
                    ammunationPromptVisible = true
                end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('rp_businesses:server:requestAmmunation')
                    Wait(350)
                end
            elseif ammunationPromptVisible then
                exports['rp_ui']:HideTextUI()
                ammunationPromptVisible = false
            end
        elseif ammunationPromptVisible then
            exports['rp_ui']:HideTextUI()
            ammunationPromptVisible = false
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeAmmunationTablet()
    if ammunationPromptVisible then exports['rp_ui']:HideTextUI() end
end)


-- Supérettes : vendeurs PNJ persistants à proximité et ouverture avec E.
local groceryPeds = {}
local groceryLocations = {}
local groceryTabletOpen = false
local groceryPromptVisible = false
local groceryPedModel = joaat('mp_m_shopkeep_01')

local function loadGroceryPed(location)
    local point = vector3(location.x, location.y, location.z)
    if #(GetEntityCoords(PlayerPedId()) - point) > 85.0 then return end
    if groceryPeds[location.key] and DoesEntityExist(groceryPeds[location.key]) then return end
    RequestModel(groceryPedModel)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(groceryPedModel) and GetGameTimer() < timeout do Wait(50) end
    if not HasModelLoaded(groceryPedModel) then return end
    local found, groundZ = GetGroundZFor_3dCoord(location.x, location.y, location.z + 2.0, false)
    local z = found and groundZ or location.z
    local ped = CreatePed(4, groceryPedModel, location.x, location.y, z, 0.0, false, true)
    if ped and ped ~= 0 then
        SetEntityAsMissionEntity(ped, true, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
        groceryPeds[location.key] = ped
    end
    SetModelAsNoLongerNeeded(groceryPedModel)
end

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    groceryLocations = {}
    for _, location in ipairs(locations) do
        if location.location_type == 'shop' and location.shop_style == 'food' then
            groceryLocations[#groceryLocations + 1] = {
                key = tostring(location.location_key or (#groceryLocations + 1)),
                x = tonumber(location.x), y = tonumber(location.y), z = tonumber(location.z)
            }
        end
    end
end)

RegisterNetEvent('rp_businesses:client:openStore', function(payload)
    if type(payload) ~= 'table' then return end
    if groceryPromptVisible then exports['rp_ui']:HideTextUI(); groceryPromptVisible = false end
    groceryTabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openStore', cash = tonumber(payload.cash) or 0,
        storeName = tostring(payload.storeName or 'SUPÉRETTE'), products = payload.products or {} })
end)

RegisterNetEvent('rp_businesses:client:storePurchaseResult', function(result)
    if type(result) ~= 'table' then return end
    SendNUIMessage({ action = 'storePurchaseResult', success = result.success == true,
        message = tostring(result.message or ''), cash = tonumber(result.cash) or 0 })
end)

RegisterNUICallback('closeStore', function(_, cb)
    groceryTabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeStore' })
    cb({ ok = true })
end)

RegisterNUICallback('buyStoreItem', function(data, cb)
    if type(data) ~= 'table' or type(data.item) ~= 'string' then cb({ ok = false }); return end
    TriggerServerEvent('rp_businesses:server:buyStoreItem', data.item)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        local sleep = 1200
        if not groceryTabletOpen and #groceryLocations > 0 and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for _, location in ipairs(groceryLocations) do
                local distance = #(coords - vector3(location.x, location.y, location.z))
                if not nearestDistance or distance < nearestDistance then nearest, nearestDistance = location, distance end
            end
            if nearest and nearestDistance <= 85.0 then
                sleep = 500
                loadGroceryPed(nearest)
            end
            if nearest and nearestDistance <= 2.2 then
                sleep = 0
                if not groceryPromptVisible then
                    exports['rp_ui']:ShowTextUI('[E] Ouvrir la boutique')
                    groceryPromptVisible = true
                end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('rp_businesses:server:requestStore')
                    Wait(400)
                end
            elseif groceryPromptVisible then
                exports['rp_ui']:HideTextUI()
                groceryPromptVisible = false
            end
        elseif groceryPromptVisible then
            exports['rp_ui']:HideTextUI()
            groceryPromptVisible = false
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        for key, ped in pairs(groceryPeds) do
            if not DoesEntityExist(ped) then groceryPeds[key] = nil end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, ped in pairs(groceryPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
