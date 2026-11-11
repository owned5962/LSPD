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

local function SendInventoryToNui(data, action)
    SendNUIMessage({
        action = action,
        inventory = data.inventory or {},
        maxWeight = Config.MaxWeight or 30.0,
        currentWeight = data.currentWeight or 0.0,
        cash = data.cash or 0,
        bank = data.bank or 0
    })
end

RegisterNetEvent('rp_inventory:receiveData', function(data)
    if type(data) ~= 'table' then
        isInventoryPending = false
        SetNuiFocus(false, false)
        return
    end
    isInventoryPending = false
    isInventoryOpen = true
    SetNuiFocus(true, true)
    SendInventoryToNui(data, 'open')
end)

RegisterNetEvent('rp_inventory:updateData', function(data)
    if type(data) ~= 'table' or not isInventoryOpen then return end
    SendInventoryToNui(data, 'update')
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
        TriggerEvent('rp_core:client:notify', 'Aucun citoyen à proximité !', 'error')
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


local groundDrops = {}

RegisterNetEvent('rp_inventory:client:syncDrops', function(drops)
    groundDrops = type(drops) == 'table' and drops or {}
end)

RegisterNetEvent('rp_inventory:client:removeDrop', function(dropId)
    dropId = tostring(dropId or '')
    if dropId == '' then return end
    for index = #groundDrops, 1, -1 do
        if tostring(groundDrops[index].id) == dropId then table.remove(groundDrops, index) end
    end
end)

local function DrawDropText(coords, label)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z + 0.35)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(label)
    DrawText(screenX, screenY)
end

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('rp_inventory:server:requestDrops')
    while true do
        local waitTime = 750
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local closest, closestDistance
        for _, drop in ipairs(groundDrops) do
            local dropCoords = vector3(tonumber(drop.x) or 0.0, tonumber(drop.y) or 0.0, tonumber(drop.z) or 0.0)
            local distance = #(coords - dropCoords)
            if distance < 15.0 then
                waitTime = 0
                DrawMarker(2, dropCoords.x, dropCoords.y, dropCoords.z + 0.12,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.18, 0.18, 0.18,
                    56, 189, 248, 170, false, true, 2, false, nil, nil, false)
                if not closestDistance or distance < closestDistance then
                    closest, closestDistance = drop, distance
                end
            end
        end
        if closest and closestDistance <= 2.0 and not isInventoryOpen then
            DrawDropText(vector3(tonumber(closest.x), tonumber(closest.y), tonumber(closest.z)),
                ('[E] Ramasser %s x%d'):format(closest.label or 'Objet', tonumber(closest.count) or 1))
            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('rp_inventory:server:pickupDrop', tostring(closest.id))
                Wait(700)
            end
        end
        Wait(waitTime)
    end
end)

RegisterNetEvent('rp_inventory:applyMedicalItem', function(heal)
    local ped = PlayerPedId()
    local amount = tonumber(heal)
    if not amount or amount <= 0 or IsEntityDead(ped) then return end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
    ClearPedBloodDamage(ped)
end)

-- Les armes sont conservées dans les métadonnées du personnage et restaurées
-- après la création du ped, une fois l'apparence et le spawn terminés.
RegisterNetEvent('rp_characters:client:spawnPlayer', function()
    CreateThread(function()
        Wait(3000)
        TriggerServerEvent('rp_inventory:server:requestWeapons')
    end)
end)

RegisterNetEvent('rp_inventory:client:restoreWeapons', function(weapons)
    if type(weapons) ~= 'table' then return end
    local ped = PlayerPedId()
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    for _, entry in ipairs(weapons) do
        if type(entry) == 'table' and type(entry.name) == 'string'
            and entry.name:match('^WEAPON_[A-Z0-9_]+$') then
            local hash = GetHashKey(entry.name)
            if IsWeaponValid(hash) then
                local ammo = math.max(0, math.min(9999, math.floor(tonumber(entry.ammo) or 0)))
                GiveWeaponToPed(ped, hash, ammo, false, false)
                SetPedAmmo(ped, hash, ammo)
            end
        end
    end
end)

