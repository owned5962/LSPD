local createdBlips = {}
local locationsLoaded = false

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
    for _, location in ipairs(locations) do
        addLocationBlip(location)
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
