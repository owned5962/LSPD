local isInventoryOpen = false
local isInventoryPending = false
local lastToggleAt = 0

local function CloseInventory()
    isInventoryPending = false
    isInventoryOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function OpenInventory()
    if isInventoryPending or isInventoryOpen then return end
    isInventoryPending = true
    TriggerServerEvent('rp_inventory:requestData')

    SetTimeout(5000, function()
        if isInventoryPending and not isInventoryOpen then
            isInventoryPending = false
            SetNuiFocus(false, false)
            TriggerEvent('rp_core:client:notify',
                'L’inventaire ne répond pas. Vérifiez que votre personnage est bien chargé, puis réessayez.', 'error')
        end
    end)
end

local function ToggleInventory()
    -- RegisterKeyMapping and the native-control fallback can fire on the same
    -- frame. Debounce them so one F2 press can never open and close instantly.
    local now = GetGameTimer()
    if lastToggleAt > 0 and now - lastToggleAt < 300 then return end
    lastToggleAt = now

    if isInventoryOpen or isInventoryPending then
        CloseInventory()
    else
        OpenInventory()
    end
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isInventoryOpen = false
    isInventoryPending = false
    lastToggleAt = 0
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)

-- Use a fresh command name so stale FiveM player keybinds from previous
-- inventory versions cannot override the current F2 mapping.
local INVENTORY_KEY_COMMAND = 'rp_inventory_tablet_toggle_f2'
RegisterCommand(INVENTORY_KEY_COMMAND, ToggleInventory, false)
RegisterKeyMapping(INVENTORY_KEY_COMMAND, 'Ouvrir / fermer l’inventaire', 'keyboard', 'F2')
RegisterNetEvent('rp_inventory:client:toggle', ToggleInventory)

-- Fallback for clients where the F2 key mapping is not registered/applied.
-- Config.OpenKey is the inventory's existing F2 control (289).
CreateThread(function()
    while true do
        Wait(0)
        if not IsPauseMenuActive()
            and not IsControlPressed(0, 200)
            and IsControlJustPressed(0, Config.OpenKey or 289) then
            ToggleInventory()
        end
    end
end)

RegisterNetEvent('rp_inventory:receiveData', function(data)
    if type(data) ~= 'table' then
        isInventoryPending = false
        SetNuiFocus(false, false)
        return
    end

    isInventoryPending = false
    isInventoryOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        inventory = data.inventory or {},
        maxWeight = Config.MaxWeight or 30.0,
        currentWeight = data.currentWeight or 0.0,
        cash = data.cash or 0,
        bank = data.bank or 0
    })
end)

RegisterNetEvent('rp_inventory:requestFailed', function(message)
    isInventoryPending = false
    isInventoryOpen = false
    SetNuiFocus(false, false)
    TriggerEvent('rp_core:client:notify', message or 'Impossible d’ouvrir votre inventaire.', 'error')
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
        TriggerEvent('rp_core:client:notify', 'error', 'Aucun citoyen à proximité !')
    end
    cb('ok')
end)

local function GetClosestPlayer()
    local players = GetActivePlayers()
    local coords = GetEntityCoords(PlayerPedId())
    local closestDistance = -1
    local closestPlayer = -1

    for i = 1, #players do
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
