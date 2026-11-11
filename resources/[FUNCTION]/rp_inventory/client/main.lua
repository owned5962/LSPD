local isInventoryOpen = false

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isInventoryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)

RegisterKeyMapping('openinventory', 'Ouvrir l\'inventaire', 'keyboard', 'F2')

RegisterCommand('openinventory', function()
    if not isInventoryOpen then
        OpenInventory()
    else
        CloseInventory()
    end
end, false)

function OpenInventory()
    isInventoryOpen = true
    SetNuiFocus(true, true)
    TriggerServerEvent('rp_inventory:requestData')
end

function CloseInventory()
    isInventoryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('rp_inventory:receiveData', function(data)
    SendNUIMessage({
        action = 'open',
        inventory = data.inventory or {},
        maxWeight = Config.MaxWeight,
        currentWeight = data.currentWeight or 0.0,
        cash = data.cash or 0,
        bank = data.bank or 0
    })
end)

RegisterNUICallback('close', function(data, cb)
    CloseInventory()
    cb('ok')
end)

RegisterNUICallback('useItem', function(data, cb)
    TriggerServerEvent('rp_inventory:useItem', data.item)
    cb('ok')
end)

RegisterNUICallback('dropItem', function(data, cb)
    TriggerServerEvent('rp_inventory:dropItem', data.item, tonumber(data.count) or 1)
    cb('ok')
end)

RegisterNUICallback('giveItem', function(data, cb)
    local closestPlayer, closestDistance = GetClosestPlayer()
    if closestPlayer ~= -1 and closestDistance <= 3.0 then
        TriggerServerEvent('rp_inventory:giveItem', GetPlayerServerId(closestPlayer), data.item, tonumber(data.count) or 1)
    else
        TriggerEvent('rp_core:notify', 'error', 'Aucun citoyen à proximité!')
    end
    cb('ok')
end)

function GetClosestPlayer()
    local players = GetActivePlayers()
    local coords = GetEntityCoords(PlayerPedId())
    local closestDistance = -1
    local closestPlayer = -1

    for i = 1, #players, 1 do
        local target = GetPlayerPed(players[i])
        if target ~= PlayerPedId() then
            local targetCoords = GetEntityCoords(target)
            local distance = #(coords - targetCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = players[i]
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

RegisterNetEvent('rp_inventory:applyMedicalItem', function(heal)
    local ped = PlayerPedId()
    local amount = tonumber(heal)
    if not amount or amount <= 0 or IsEntityDead(ped) then return end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
    ClearPedBloodDamage(ped)
end)
