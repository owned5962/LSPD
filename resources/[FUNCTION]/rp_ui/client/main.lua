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
