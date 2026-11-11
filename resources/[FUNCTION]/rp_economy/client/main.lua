local isBankOpen = false

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
            banks[#banks + 1] = {
                x = tonumber(location.x), y = tonumber(location.y), z = tonumber(location.z),
                label = location.name or 'Guichet bancaire'
            }
        end
    end
    if #banks > 0 then BankPositions = banks end
end)

local ATMModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' }

local function GetNearbyATM(maxDistance)
    local coords = GetEntityCoords(PlayerPedId())
    for _, model in ipairs(ATMModels) do
        local object = GetClosestObjectOfType(coords.x, coords.y, coords.z, maxDistance or 1.8, GetHashKey(model), false, false, false)
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

function OpenBankUI(isATM)
    if isBankOpen then return end
    if isATM then
        if GetNearbyATM(2.0) == 0 then TriggerEvent('rp_core:client:notify', 'Approchez-vous d’un distributeur.', 'error'); return end
    elseif not GetNearbyBank(3.0) then
        TriggerEvent('rp_core:client:notify', 'Approchez-vous d’une banque.', 'error')
        return
    end
    exports['rp_ui']:HideTextUI()
    local pData = exports['rp_core']:GetPlayerData()
    isBankOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openBank",
        isATM = isATM or false,
        cash = pData.cash or 0,
        bank = pData.bank or 0,
        playerName = (pData.firstname or 'Citoyen') .. ' ' .. (pData.lastname or ''),
        accountNumber = "LS-" .. tostring(pData.charId or 1001)
    })
end

function CloseBankUI()
    isBankOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeBank" })
end

RegisterCommand('bank', function()
    OpenBankUI(false)
end, false)

RegisterCommand('atm', function()
    OpenBankUI(true)
end, false)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isBankOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeBank' })
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    isBankOpen = false
    SetNuiFocus(false, false)
    exports['rp_ui']:HideTextUI()
end)

CreateThread(function()
    local activePrompt = nil
    while true do
        local waitTime = 900
        if not isBankOpen then
            local nearbyBank, bankDistance = GetNearbyBank(12.0)
            local atm = GetNearbyATM(2.0)
            if atm ~= 0 then
                waitTime = 0
                exports['rp_ui']:ShowTextUI('[E] Utiliser le distributeur')
                activePrompt = 'atm'
                if IsControlJustReleased(0, 38) then OpenBankUI(true); activePrompt = nil end
            elseif nearbyBank then
                waitTime = 0
                if bankDistance < 2.2 then
                    exports['rp_ui']:ShowTextUI('[E] Accéder au guichet bancaire')
                    activePrompt = 'bank'
                    if IsControlJustReleased(0, 38) then OpenBankUI(false); activePrompt = nil end
                else
                    if activePrompt then exports['rp_ui']:HideTextUI(); activePrompt = nil end
                    DrawMarker(2, nearbyBank.x, nearbyBank.y, nearbyBank.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.25, 35, 190, 130, 130, false, true, 2, false, nil, nil, false)
                end
            else
                if activePrompt then exports['rp_ui']:HideTextUI(); activePrompt = nil end
            end
        else
            waitTime = 500
            if activePrompt then exports['rp_ui']:HideTextUI(); activePrompt = nil end
        end
        Wait(waitTime)
    end
end)

RegisterNUICallback('close', function(data, cb)
    CloseBankUI()
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('rp_economy:server:deposit', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('rp_economy:server:withdraw', tonumber(data.amount))
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    TriggerServerEvent('rp_economy:server:transfer', tonumber(data.targetId), tonumber(data.amount))
    cb('ok')
end)

RegisterNetEvent('rp_economy:client:refreshBalances', function(cash, bank)
    SendNUIMessage({
        action = "updateBalances",
        cash = cash,
        bank = bank
    })
end)
