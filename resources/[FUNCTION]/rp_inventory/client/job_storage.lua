local marker = nil
local storageData = nil
local storageType = 'stash'
local direction = 'withdraw'
local selectedIndex = 1
local amount = 1
local menuOpen = false
local menuPending = false
local promptShown = false
local currentText = nil

local function hideText()
    if promptShown then
        exports['rp_ui']:HideTextUI()
        promptShown = false
        currentText = nil
    end
end

local function showText(value)
    if currentText == value then return end
    exports['rp_ui']:ShowTextUI(value)
    currentText = value
    promptShown = true
end

local function requestMarker()
    TriggerServerEvent('rp_inventory:server:requestJobStorageMarker')
end

local function currentItems()
    if not storageData then return {} end
    return direction == 'withdraw' and (storageData.storageItems or {}) or (storageData.inventoryItems or {})
end

local function renderMenu()
    if not storageData then return end
    local items = currentItems()
    if #items == 0 then
        showText(('[%s] %s · Aucun objet · [H] %s · [G] Changer · [ÉCHAP] Fermer'):format(
            storageType == 'stash' and 'COFFRE' or 'ARMURERIE',
            direction == 'withdraw' and 'Retrait' or 'Dépôt',
            direction == 'withdraw' and 'Déposer' or 'Retirer'))
        return
    end
    selectedIndex = math.max(1, math.min(selectedIndex, #items))
    local item = items[selectedIndex]
    local available = tonumber(item.count) or 0
    showText(('[%s] %s · %s x%d · Qté %d · [←/→] Objet [↑/↓] Qté [H] %s [E] Valider [G] Changer [ÉCHAP] Fermer'):format(
        storageType == 'stash' and 'COFFRE' or 'ARMURERIE',
        direction == 'withdraw' and 'Retrait' or 'Dépôt',
        item.label or item.name, available, amount,
        direction == 'withdraw' and 'Déposer' or 'Retirer'))
end

local function openStorage(kind)
    if menuOpen or menuPending or not marker then return end
    if kind == 'stash' and not marker.stashEnabled then return end
    if kind == 'armory' and not marker.armoryEnabled then return end
    storageType = kind
    menuPending = true
    TriggerServerEvent('rp_inventory:server:openJobStorage', kind)
    SetTimeout(3000, function()
        if menuPending and not menuOpen then
            menuPending = false
            hideText()
            TriggerEvent('rp_core:client:notify', 'Le coffre métier ne répond pas.', 'error')
        end
    end)
end

RegisterNetEvent('rp_inventory:client:jobStorageMarker', function(data)
    if type(data) ~= 'table' then
        marker = nil
        if not menuOpen then hideText() end
        return
    end
    marker = {
        coords = vector3(tonumber(data.x) or 0.0, tonumber(data.y) or 0.0, tonumber(data.z) or 0.0),
        stashEnabled = data.stashEnabled == true,
        armoryEnabled = data.armoryEnabled == true
    }
end)

RegisterNetEvent('rp_inventory:client:jobStorageData', function(data)
    if type(data) ~= 'table' or type(data.storageItems) ~= 'table' or type(data.inventoryItems) ~= 'table' then
        menuPending = false
        return
    end
    storageData = data
    storageType = data.storageType
    menuPending = false
    menuOpen = true
    selectedIndex = 1
    amount = 1
    renderMenu()
end)

CreateThread(function()
    Wait(2500)
    requestMarker()
    while true do
        Wait(15000)
        requestMarker()
    end
end)

CreateThread(function()
    while true do
        local waitTime = 650
        if menuOpen and storageData then
            waitTime = 0
            local items = currentItems()
            if IsControlJustReleased(0, 174) then
                selectedIndex = selectedIndex > 1 and selectedIndex - 1 or math.max(1, #items)
                renderMenu()
            elseif IsControlJustReleased(0, 175) then
                selectedIndex = selectedIndex < #items and selectedIndex + 1 or 1
                renderMenu()
            elseif IsControlJustReleased(0, 172) then
                amount = math.min(20, amount + 1)
                renderMenu()
            elseif IsControlJustReleased(0, 173) then
                amount = math.max(1, amount - 1)
                renderMenu()
            elseif IsControlJustReleased(0, 74) then
                direction = direction == 'withdraw' and 'deposit' or 'withdraw'
                selectedIndex = 1
                renderMenu()
            elseif IsControlJustReleased(0, 38) then
                local item = items[selectedIndex]
                if item then
                    TriggerServerEvent('rp_inventory:server:transferJobStorage',
                        storageType, direction, item.name, math.min(amount, tonumber(item.count) or 1))
                end
            elseif IsControlJustReleased(0, 47) then
                local nextType = storageType == 'stash' and 'armory' or 'stash'
                if marker and ((nextType == 'stash' and marker.stashEnabled) or (nextType == 'armory' and marker.armoryEnabled)) then
                    menuOpen = false
                    storageData = nil
                    openStorage(nextType)
                end
            elseif IsControlJustReleased(0, 200) or IsControlJustReleased(0, 177) then
                menuOpen = false
                menuPending = false
                storageData = nil
                hideText()
            end
        elseif marker and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local distance = #(coords - marker.coords)
            if distance <= 2.5 then
                waitTime = 0
                local prompt = '[E] Coffre métier'
                if marker.armoryEnabled then prompt = prompt .. ' · [G] Armurerie' end
                showText(prompt)
                if IsControlJustReleased(0, 38) then
                    if marker.stashEnabled then openStorage('stash')
                    elseif marker.armoryEnabled then openStorage('armory') end
                elseif IsControlJustReleased(0, 47) and marker.armoryEnabled then
                    openStorage('armory')
                end
            else
                hideText()
            end
        else
            if not menuOpen then hideText() end
        end
        Wait(waitTime)
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then hideText() end
end)
