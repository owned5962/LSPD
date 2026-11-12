local isBankOpen = false
local isAuthenticated = false
local isAuthenticating = false
local openedAt = nil
local openedAsATM = false
local openedLocationLabel = 'Agence bancaire'

local BankPositions = {
    { x = 149.9, y = -1040.5, z = 29.3, label = "Fleeca Bank Legion Square" },
    { x = -1212.9, y = -330.8, z = 37.7, label = "Fleeca Bank Boulevard Del Perro" },
    { x = -2962.6, y = 482.1, z = 15.7, label = "Fleeca Bank Great Ocean Hwy" },
    { x = 1175.0, y = 2706.8, z = 38.0, label = "Fleeca Bank Sandy Shores" },
    { x = 236.4, y = 217.4, z = 106.2, label = "Pacific Standard Public Bank" }
}

RegisterNetEvent('rp_businesses:client:locations', function(locations)
    if type(locations) ~= 'table' then return end
    local banks = {}
    for _, location in ipairs(locations) do
        if location.location_type == 'bank' then
            local x, y, z = tonumber(location.x), tonumber(location.y), tonumber(location.z)
            if x and y and z then
                banks[#banks + 1] = {
                    x = x, y = y, z = z,
                    label = location.name or 'Guichet bancaire'
                }
            end
        end
    end
    if #banks > 0 then BankPositions = banks end
end)

local ATMModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }

local function GetNearbyATM(maxDistance)
    local coords = GetEntityCoords(PlayerPedId())
    for _, model in ipairs(ATMModels) do
        local object = GetClosestObjectOfType(coords.x, coords.y, coords.z, maxDistance or 1.8, joaat(model), false, false, false)
        if object and object ~= 0 and DoesEntityExist(object) then return object end
    end
    return 0
end

local function GetNearbyBank(maxDistance)
    local coords = GetEntityCoords(PlayerPedId())
    local nearest, nearestDistance = nil, maxDistance or 2.0
    for _, bank in ipairs(BankPositions) do
        local distance = #(coords - vector3(bank.x, bank.y, bank.z))
        if distance <= nearestDistance then nearest, nearestDistance = bank, distance end
    end
    return nearest, nearestDistance
end

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', tostring(message or ''), kind or 'info')
end

local function CloseBankUI()
    if not isBankOpen then return end
    isBankOpen = false
    isAuthenticated = false
    isAuthenticating = false
    openedAt = nil
    TriggerServerEvent('rp_economy:server:logout')
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeBank' })
end

local function OpenBankUI(isATM)
    if isBankOpen then return end
    local locationLabel
    if isATM then
        local atm = GetNearbyATM(1.0)
        if atm == 0 then
            notify('Approchez-vous d’un distributeur automatique.', 'error')
            return
        end
        locationLabel = 'Distributeur automatique · 24/7'
        openedAt = GetEntityCoords(atm)
    else
        local bank = GetNearbyBank(1.0)
        if not bank then
            notify('Approchez-vous du guichet d’une agence bancaire.', 'error')
            return
        end
        locationLabel = bank.label
        openedAt = vector3(bank.x, bank.y, bank.z)
    end

    local readyOk, ready = pcall(function()
        return exports['rp_core']:WaitForPlayerLoaded(5000)
    end)
    if not readyOk or ready ~= true then
        openedAt = nil
        notify('Les données de votre personnage ne sont pas encore synchronisées. Réessayez dans quelques secondes.', 'warning')
        return
    end

    local ok, playerData = pcall(function()
        return exports['rp_core']:GetPlayerData()
    end)
    if not ok or type(playerData) ~= 'table' or not tonumber(playerData.charId) then
        openedAt = nil
        notify('Les données du personnage sont indisponibles. Réessayez dans quelques secondes.', 'error')
        return
    end

    exports['rp_ui']:HideTextUI()
    isBankOpen = true
    isAuthenticated = false
    isAuthenticating = false
    openedAsATM = isATM == true
    openedLocationLabel = locationLabel
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = 'openBank',
        isATM = openedAsATM,
        locationLabel = openedLocationLabel,
        playerName = (playerData.firstname or 'Citoyen') .. ' ' .. (playerData.lastname or ''),
        accountNumber = ('LS-%06d'):format(tonumber(playerData.charId) or 0)
    })
end

RegisterCommand('bank', function()
    OpenBankUI(false)
end, false)

RegisterCommand('atm', function()
    OpenBankUI(true)
end, false)

RegisterNUICallback('close', function(_, cb)
    CloseBankUI()
    cb({ ok = true })
end)

RegisterNUICallback('authenticate', function(_, cb)
    if not isBankOpen or isAuthenticated or isAuthenticating then cb({ ok = false }); return end
    isAuthenticating = true
    TriggerServerEvent('rp_economy:server:authenticate')
    SetTimeout(10000, function()
        if isAuthenticating then
            isAuthenticating = false
            if isBankOpen then
                SendNUIMessage({ action = 'authenticationFailed', message = 'Le lecteur ne répond pas. Vérifiez votre position et réessayez.' })
            end
        end
    end)
    cb({ ok = true })
end)

RegisterNUICallback('deposit', function(data, cb)
    if not isBankOpen or not isAuthenticated then cb({ ok = false }); return end
    TriggerServerEvent('rp_economy:server:deposit', tonumber(data.amount))
    cb({ ok = true })
end)

RegisterNUICallback('withdraw', function(data, cb)
    if not isBankOpen or not isAuthenticated then cb({ ok = false }); return end
    TriggerServerEvent('rp_economy:server:withdraw', tonumber(data.amount))
    cb({ ok = true })
end)

RegisterNUICallback('transfer', function(data, cb)
    if not isBankOpen or not isAuthenticated or openedAsATM then cb({ ok = false }); return end
    TriggerServerEvent('rp_economy:server:transfer', tonumber(data.targetId), tonumber(data.amount))
    cb({ ok = true })
end)

RegisterNetEvent('rp_economy:client:authenticationResult', function(result)
    isAuthenticating = false
    if not isBankOpen then return end
    if type(result) ~= 'table' or result.success ~= true then
        SendNUIMessage({ action = 'authenticationFailed', message = result and result.message or 'Empreinte non reconnue.' })
        return
    end
    isAuthenticated = true
    SendNUIMessage({
        action = 'authenticationSuccess',
        cash = tonumber(result.cash) or 0,
        bank = tonumber(result.bank) or 0,
        playerName = result.playerName or 'Citoyen',
        accountNumber = result.accountNumber or 'Compte LSS'
    })
end)

RegisterNetEvent('rp_economy:client:sessionExpired', function()
    if not isBankOpen then return end
    isAuthenticated = false
    SendNUIMessage({ action = 'authenticationExpired' })
end)

RegisterNetEvent('rp_economy:client:refreshBalances', function(cash, bank)
    if isBankOpen and isAuthenticated then
        SendNUIMessage({ action = 'updateBalances', cash = cash, bank = bank })
    end
end)

RegisterNetEvent('rp_economy:client:bankNotice', function(message, kind)
    if isBankOpen then SendNUIMessage({ action = 'bankNotice', message = message, kind = kind or 'info' }) end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isBankOpen = false
    isAuthenticated = false
    isAuthenticating = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeBank' })
    SetTimeout(2000, function()
        TriggerServerEvent('rp_businesses:server:requestLocations')
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isBankOpen = false
    isAuthenticated = false
    isAuthenticating = false
    TriggerServerEvent('rp_economy:server:logout')
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    exports['rp_ui']:HideTextUI()
end)

CreateThread(function()
    local activePrompt = nil
    while true do
        local waitTime = 900
        if not isBankOpen then
            local nearbyBank, bankDistance = GetNearbyBank(1.0)
            local atm = GetNearbyATM(1.0)
            if atm ~= 0 then
                waitTime = 0
                if activePrompt ~= 'atm' then
                    exports['rp_ui']:ShowTextUI('[E] Utiliser le distributeur')
                    activePrompt = 'atm'
                end
                if IsControlJustReleased(0, 38) then OpenBankUI(true) end
            elseif nearbyBank and bankDistance <= 1.0 then
                waitTime = 0
                if activePrompt ~= 'bank' then
                    exports['rp_ui']:ShowTextUI('[E] Accéder au guichet bancaire')
                    activePrompt = 'bank'
                end
                if IsControlJustReleased(0, 38) then OpenBankUI(false) end
            elseif nearbyBank then
                if activePrompt then exports['rp_ui']:HideTextUI(); activePrompt = nil end
                DrawMarker(2, nearbyBank.x, nearbyBank.y, nearbyBank.z + 0.15,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    0.35, 0.35, 0.25, 35, 190, 130, 130, false, true, 2, false, nil, nil, false)
            else
                if activePrompt then exports['rp_ui']:HideTextUI(); activePrompt = nil end
            end
        else
            waitTime = 250
            if activePrompt then exports['rp_ui']:HideTextUI(); activePrompt = nil end
            if openedAt and #(GetEntityCoords(PlayerPedId()) - openedAt)  > 1.0 then
                CloseBankUI()
                notify('Session bancaire fermée : vous vous êtes éloigné du terminal.', 'warning')
            end
        end
        Wait(waitTime)
    end
end)
