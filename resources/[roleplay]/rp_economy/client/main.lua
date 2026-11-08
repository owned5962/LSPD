local isBankOpen = false

local BankPositions = {
    { x = 149.9, y = -1040.5, z = 29.3, label = "Fleeca Bank Legion Square" },
    { x = -1212.9, y = -330.8, z = 37.7, label = "Fleeca Bank Boulevard Del Perro" },
    { x = -2962.6, y = 482.1, z = 15.7, label = "Fleeca Bank Great Ocean Hwy" },
    { x = 1175.0, y = 2706.8, z = 38.0, label = "Fleeca Bank Sandy Shores" },
    { x = 236.4, y = 217.4, z = 106.2, label = "Pacific Standard Public Bank" }
}

CreateThread(function()
    for _, bank in ipairs(BankPositions) do
        local blip = AddBlipForCoord(bank.x, bank.y, bank.z)
        SetBlipSprite(blip, 108)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(bank.label)
        EndTextCommandSetBlipName(blip)
    end
end)

function OpenBankUI(isATM)
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
