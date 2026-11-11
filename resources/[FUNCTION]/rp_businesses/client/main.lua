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

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    for _, blip in ipairs(createdBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    createdBlips = {}
    for _, location in ipairs(locations) do
        addLocationBlip(location)
    end
    locationsLoaded = true
end)

local function requestLocations()
    TriggerServerEvent('rp_businesses:server:requestLocations')
end

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
