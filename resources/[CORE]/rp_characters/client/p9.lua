            SetEntityCollision(currentPed, true, true)
        end
        return false
    end
    local ped = PlayerPedId()

    -- GTA freemode genetic inheritance and facial morphs.
    if type(skin.headBlend) == 'table' then
        local blend = skin.headBlend
        local function blendId(key, fallback)
            local value = tonumber(blend[key])
            if not value or value % 1 ~= 0 then return fallback end
            return math.max(0, math.min(45, value))
        end
        local function blendMix(key, fallback)
            local value = tonumber(blend[key])
            if not value or value ~= value then return fallback end
            return math.max(0.0, math.min(1.0, value))
        end
        SetPedHeadBlendData(ped,
            blendId('shapeFirst', 0), blendId('shapeSecond', 21), blendId('shapeThird', 0),
            blendId('skinFirst', 0), blendId('skinSecond', 21), blendId('skinThird', 0),
            blendMix('shapeMix', 0.5), blendMix('skinMix', 0.5), blendMix('thirdMix', 0.0), false)
        -- Force GTA to refresh the blended face after parent and mix sliders change.
        UpdatePedHeadBlendData(ped, true)
    end

