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


-- Ammu-Nation : les points partagés sont disponibles immédiatement, sans attendre MySQL.
local ammunationLocations = {}
local ammunationPromptVisible = false
local ammunationTabletOpen = false

local function addAmmunationLocation(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end
    for _, existing in ipairs(ammunationLocations) do
        if #(existing - vector3(x, y, z)) < 1.0 then return end
    end
    ammunationLocations[#ammunationLocations + 1] = vector3(x, y, z)
end

for _, category in ipairs(BusinessLocations or {}) do
    if category.id == 'ammunation' then
        for _, point in ipairs(category.points or {}) do
            addAmmunationLocation(point[1], point[2], point[3])
        end
    end
end

local function closeAmmunationTablet()
    if not ammunationTabletOpen then return end
    ammunationTabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeAmmunation' })
end

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    for _, location in ipairs(locations) do
        if location.location_type == 'shop' and location.shop_style == 'ammunation' then
            addAmmunationLocation(location.x, location.y, location.z)
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
        local sleep = 700
        if ammunationTabletOpen then
            sleep = 250
        elseif #ammunationLocations > 0 and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local nearestHorizontal, nearestVertical
            for _, shopCoords in ipairs(ammunationLocations) do
                local dx, dy = coords.x - shopCoords.x, coords.y - shopCoords.y
                local horizontal = math.sqrt(dx * dx + dy * dy)
                local vertical = math.abs(coords.z - shopCoords.z)
                if not nearestHorizontal or horizontal < nearestHorizontal then
                    nearestHorizontal, nearestVertical = horizontal, vertical
                end
            end

            if nearestHorizontal and nearestHorizontal <= 6.0 and nearestVertical <= 10.0 then
                sleep = 0
                if not ammunationPromptVisible then
                    exports['rp_ui']:ShowTextUI('[E] Ouvrir la tablette Ammu-Nation')
                    ammunationPromptVisible = true
                end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('rp_businesses:server:requestAmmunation')
                    Wait(500)
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

-- Supérettes : vendeurs PNJ et ouverture de la tablette avec E.
local groceryPeds = {}
local groceryLocations = {}
local groceryTabletOpen = false
local groceryPromptVisible = false
local groceryPedModels = { 'mp_m_shopkeep_01', 's_f_y_shop_mid', 's_m_m_linecook' }

local function addGroceryLocation(key, x, y, z, heading)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end
    key = tostring(key or (#groceryLocations + 1))
    for _, existing in ipairs(groceryLocations) do
        if existing.key == key then
            existing.x, existing.y, existing.z = x, y, z
            existing.heading = tonumber(heading) or existing.heading or 0.0
            return
        end
    end
    groceryLocations[#groceryLocations + 1] = {
        key = key, x = x, y = y, z = z, heading = tonumber(heading) or 0.0
    }
end

-- Static locations are loaded with the resource; NPCs therefore do not depend
-- on the asynchronous MySQL location response to appear.
for _, category in ipairs(BusinessLocations or {}) do
    if category.id == 'food' then
        for index, point in ipairs(category.points or {}) do
            addGroceryLocation(('shop:food:%d'):format(index), point[1], point[2], point[3], point[4])
        end
    end
end

local function loadGroceryPed(location)
    local point = vector3(location.x, location.y, location.z)
    if #(GetEntityCoords(PlayerPedId()) - point) > 100.0 then return end
    local existing = groceryPeds[location.key]
    if existing and DoesEntityExist(existing) then return end
    groceryPeds[location.key] = nil

    local model
    for _, modelName in ipairs(groceryPedModels) do
        local candidate = joaat(modelName)
        if IsModelInCdimage(candidate) and IsModelValid(candidate) and IsModelAPed(candidate) then
            RequestModel(candidate)
            local timeout = GetGameTimer() + 4000
            while not HasModelLoaded(candidate) and GetGameTimer() < timeout do Wait(50) end
            if HasModelLoaded(candidate) then
                model = candidate
                break
            end
        end
    end

    if not model then
        print(('[rp_businesses] Aucun modèle de vendeur disponible pour %s'):format(location.key))
        return
    end

    RequestCollisionAtCoord(location.x, location.y, location.z)
    local found, groundZ = GetGroundZFor_3dCoord(location.x, location.y, location.z + 3.0, false)
    local spawnZ = found and groundZ or location.z
    local ped = CreatePed(4, model, location.x, location.y, spawnZ, location.heading or 0.0, false, true)

    if ped == 0 or not DoesEntityExist(ped) then
        print(('[rp_businesses] Échec création vendeur PNJ pour %s'):format(location.key))
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, location.heading or 0.0)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    groceryPeds[location.key] = ped
    SetModelAsNoLongerNeeded(model)
end

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    for _, location in ipairs(locations) do
        if location.location_type == 'shop' and location.shop_style == 'food' then
            addGroceryLocation(
                location.location_key,
                location.x, location.y, location.z, location.heading
            )
        end
    end
end)

RegisterNetEvent('rp_businesses:client:openStore', function(payload)
    if type(payload) ~= 'table' then return end
    if groceryPromptVisible then
        exports['rp_ui']:HideTextUI()
        groceryPromptVisible = false
    end
    groceryTabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openStore',
        cash = tonumber(payload.cash) or 0,
        storeName = tostring(payload.storeName or 'SUPÉRETTE'),
        products = type(payload.products) == 'table' and payload.products or {}
    })
end)

RegisterNetEvent('rp_businesses:client:storePurchaseResult', function(result)
    if type(result) ~= 'table' then return end
    SendNUIMessage({
        action = 'storePurchaseResult',
        success = result.success == true,
        message = tostring(result.message or ''),
        cash = tonumber(result.cash) or 0
    })
end)

RegisterNUICallback('closeStore', function(_, cb)
    groceryTabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeStore' })
    cb({ ok = true })
end)

RegisterNUICallback('buyStoreItem', function(data, cb)
    if type(data) ~= 'table' or type(data.item) ~= 'string' or #data.item > 48 then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('rp_businesses:server:buyStoreItem', data.item)
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if not groceryTabletOpen and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance

            for _, location in ipairs(groceryLocations) do
                local distance = #(coords - vector3(location.x, location.y, location.z))
                if distance <= 100.0 then
                    sleep = 350
                    loadGroceryPed(location)
                end
                if not nearestDistance or distance < nearestDistance then
                    nearest, nearestDistance = location, distance
                end
            end

            if nearest and nearestDistance <= 2.8 then
                sleep = 0
                if not groceryPromptVisible then
                    exports['rp_ui']:ShowTextUI('[E] Ouvrir la boutique')
                    groceryPromptVisible = true
                end
                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent('rp_businesses:server:requestStore')
                    Wait(500)
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
        local playerCoords = GetEntityCoords(PlayerPedId())
        for key, ped in pairs(groceryPeds) do
            if not DoesEntityExist(ped) then
                groceryPeds[key] = nil
            elseif #(playerCoords - GetEntityCoords(ped)) > 140.0 then
                DeleteEntity(ped)
                groceryPeds[key] = nil
            end
        end
        Wait(5000)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if groceryPromptVisible then exports['rp_ui']:HideTextUI() end
    for _, ped in pairs(groceryPeds) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end)
