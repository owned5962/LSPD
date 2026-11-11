local isProgressActive = false

-- Exports & Events for TextUI
function ShowTextUI(message, position)
    SendNUIMessage({
        action = 'showTextUI',
        text = message or '',
        position = position or 'right'
    })
end

function HideTextUI()
    SendNUIMessage({
        action = 'hideTextUI'
    })
end

exports('ShowTextUI', ShowTextUI)
exports('HideTextUI', HideTextUI)

RegisterNetEvent('rp_ui:showTextUI', ShowTextUI)
RegisterNetEvent('rp_ui:hideTextUI', HideTextUI)

-- Exports & Events for Progress Bar
function ProgressBar(data, cb)
    if isProgressActive then return end
    isProgressActive = true

    local duration = data.duration or 5000
    local label = data.label or 'Action en cours...'
    local canCancel = data.canCancel ~= false

    SendNUIMessage({
        action = 'startProgress',
        duration = duration,
        label = label,
        canCancel = canCancel
    })

    Citizen.CreateThread(function()
        local startTime = GetGameTimer()
        local cancelled = false

        while GetGameTimer() - startTime < duration do
            Citizen.Wait(0)
            if canCancel and IsControlJustPressed(0, 73) then -- X key to cancel
                cancelled = true
                SendNUIMessage({ action = 'cancelProgress' })
                break
            end
        end

        isProgressActive = false
        if cb then
            cb(not cancelled)
        end
    end)
end

exports('ProgressBar', ProgressBar)
RegisterNetEvent('rp_ui:startProgress', function(duration, label)
    ProgressBar({ duration = duration, label = label })
end)


-- In-game status HUD. It becomes visible only after a character is loaded.
CreateThread(function()
    local lastVisible = false
    while true do
        local waitTime = 500
        local ok, data = pcall(function() return exports['rp_core']:GetPlayerData() end)
        if ok and type(data) == 'table' and data.charId then
            local ped = PlayerPedId()
            local maxHealth = math.max(1, GetEntityMaxHealth(ped) - 100)
            local health = math.max(0, math.min(100, ((GetEntityHealth(ped) - 100) / maxHealth) * 100))
            local armor = math.max(0, math.min(100, GetPedArmour(ped)))
            SendNUIMessage({
                action = 'updateHUD',
                visible = true,
                health = math.floor(health + 0.5),
                armor = math.floor(armor + 0.5),
                hunger = math.floor(math.max(0, math.min(100, tonumber(data.hunger) or 100)) + 0.5),
                thirst = math.floor(math.max(0, math.min(100, tonumber(data.thirst) or 100)) + 0.5),
                cash = tonumber(data.cash) or 0,
                bank = tonumber(data.bank) or 0,
                job = tostring(data.jobLabel or data.job or 'Sans-emploi'),
                grade = tostring(data.jobGradeLabel or '')
            })
            if not lastVisible then DisplayRadar(true); lastVisible = true end
        else
            if lastVisible then SendNUIMessage({ action = 'hideHUD' }); lastVisible = false end
        end
        Wait(waitTime)
    end
end)
