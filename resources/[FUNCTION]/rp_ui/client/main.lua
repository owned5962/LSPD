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


-- Custom roleplay HUD. Character selection/creation hides it; it appears after
-- the character spawn event and updates only while a character is active.
local hudEnabled = false

local function SetHudVisible(visible)
    hudEnabled = visible == true
    SendNUIMessage({ action = 'setHudVisible', visible = hudEnabled })
end

RegisterNetEvent('rp_ui:setHudVisible', SetHudVisible)

RegisterNetEvent('rp_characters:client:openMenu', function()
    SetHudVisible(false)
end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function()
    SetHudVisible(false)
end)

RegisterNetEvent('rp_characters:client:spawnPlayer', function()
    SetHudVisible(true)
end)

CreateThread(function()
    while true do
        if not hudEnabled then
            Wait(1000)
        else
            local ped = PlayerPedId()
            if not DoesEntityExist(ped) then
                Wait(500)
            else
                local maxHealth = GetEntityMaxHealth(ped)
                local currentHealth = GetEntityHealth(ped)
                local healthRange = math.max(1, maxHealth - 100)
                local health = currentHealth <= 100 and 0 or ((currentHealth - 100) / healthRange) * 100
                local armour = GetPedArmour(ped)
                local vehicle = GetVehiclePedIsIn(ped, false)
                local inVehicle = vehicle ~= 0 and DoesEntityExist(vehicle)

                SendNUIMessage({
                    action = 'updateHud',
                    health = math.max(0, math.min(100, health)),
                    armour = math.max(0, math.min(100, armour)),
                    inVehicle = inVehicle,
                    speed = inVehicle and (GetEntitySpeed(vehicle) * 3.6) or 0,
                    fuel = inVehicle and GetVehicleFuelLevel(vehicle) or 0
                })
                Wait(150)
            end
        end
    end
end)
