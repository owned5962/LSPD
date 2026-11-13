local activeRescues = {}

local function isPlayerDead(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and DoesEntityExist(ped) and IsEntityDead(ped)
end

RegisterNetEvent('rp_auto_rescue:server:request', function()
    local src = source
    if not Config.Enabled or activeRescues[src] then return end
    if not exports['rp_core']:CanPerformAction(src, 'auto_rescue:request', 2500) then return end
    if not isPlayerDead(src) then return end
    activeRescues[src] = true
    TriggerClientEvent('rp_auto_rescue:client:start', src)
end)

RegisterNetEvent('rp_auto_rescue:server:finish', function()
    local src = source
    if not activeRescues[src]
        or not exports['rp_core']:CanPerformAction(src, 'auto_rescue:finish', 500) then return end
    activeRescues[src] = nil
end)

AddEventHandler('playerDropped', function()
    activeRescues[source] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then activeRescues = {} end
end)
