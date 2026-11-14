    if type(skin.faceFeatures) == 'table' then
        for feature = 0, 19 do
            local value = tonumber(skin.faceFeatures[tostring(feature)] or skin.faceFeatures[feature]) or 0.0
            if value == value then SetPedFaceFeature(ped, feature, math.max(-1.0, math.min(1.0, value))) end
        end
    end
    if type(skin.overlays) == 'table' then
        for overlay = 0, 12 do
            local item = skin.overlays[tostring(overlay)] or skin.overlays[overlay]
            if type(item) == 'table' then
                local index = math.max(0, math.min(255, math.floor(tonumber(item.index) or 0)))
                local opacity = tonumber(item.opacity) or 1.0
                SetPedHeadOverlay(ped, overlay, index, math.max(0.0, math.min(1.0, opacity)))
                local colorType = (overlay == 1 or overlay == 2 or overlay == 10) and 1 or 0
                local color = math.max(0, math.min(63, math.floor(tonumber(item.color) or 0)))
                local second = math.max(0, math.min(63, math.floor(tonumber(item.secondColor) or color)))
                SetPedHeadOverlayColor(ped, overlay, colorType, color, second)
            end
        end
    end
