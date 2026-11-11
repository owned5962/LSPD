local createdBlips = {}

local function addLocationBlip(point, category)
    local blip = AddBlipForCoord(point[1], point[2], point[3])
    SetBlipSprite(blip, category.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, category.id == 'nightclub' and 0.9 or 0.72)
    SetBlipColour(blip, category.colour)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(category.label)
    EndTextCommandSetBlipName(blip)
    createdBlips[#createdBlips + 1] = blip
end

CreateThread(function()
    for _, category in ipairs(BusinessLocations or {}) do
        for _, point in ipairs(category.points or {}) do
            addLocationBlip(point, category)
        end
    end

    for _, point in ipairs(ATMBlipLocations or {}) do
        local blip = AddBlipForCoord(point[1], point[2], point[3])
        SetBlipSprite(blip,  277)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.55)
        SetBlipColour(blip, 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Distributeur automatique')
        EndTextCommandSetBlipName(blip)
        createdBlips[#createdBlips + 1] = blip
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(createdBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
