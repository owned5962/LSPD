    local eyeColor = tonumber(skin.eyeColor) or 0
    SetPedEyeColor(ped, math.max(0, math.min(31, math.floor(eyeColor))))

    local hairStyle = tonumber(skin.hairStyle) or 0
    local hairCount = GetNumberOfPedDrawableVariations(ped, 2)
    if hairCount and hairCount > 0 then
        hairStyle = math.max(0, math.min(math.floor(hairStyle), hairCount - 1))
        SetPedComponentVariation(ped, 2, hairStyle, 0, 0)
    end
    local hairColor = math.max(0, math.min(math.floor(tonumber(skin.hairColor) or 0), 63))
    SetPedHairColor(ped, hairColor, hairColor)

    local outfits = {
        casual = { pants = 0, shoes = 1, undershirt = 15, top = 15 },
        business = { pants = 10, shoes = 10, undershirt = 10, top = 10 },
        worker = { pants = 36, shoes = 12, undershirt = 59, top = 56 },
        sport = { pants = 5, shoes = 3, undershirt = 15, top = 15 }
    }
    local outfit = outfits[skin.clothing] or outfits.casual
    local safeDefaults = {
        [3] = { 0, 0 }, [4] = { outfit.pants, 0 }, [5] = { 0, 0 },
        [6] = { outfit.shoes, 0 }, [7] = { 0, 0 }, [8] = { outfit.undershirt, 0 },
        [9] = { 0, 0 }, [10] = { 0, 0 }, [11] = { outfit.top, 0 }
    }
