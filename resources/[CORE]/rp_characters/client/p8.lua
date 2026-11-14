    SetEntityCollision(ped, true, true)
    return true
end

local function SetSafeComponent(ped, component, drawable, texture)
    local count = GetNumberOfPedDrawableVariations(ped, component)
    if not count or count < 1 then return end
    drawable = math.max(0, math.min(math.floor(tonumber(drawable) or 0), count - 1))
    local textures = GetNumberOfPedTextureVariations(ped, component, drawable)
    texture = math.max(0, math.min(math.floor(tonumber(texture) or 0), math.max(0, (textures or 1) - 1)))
    SetPedComponentVariation(ped, component, drawable, texture, 0)
end

local function ApplyCharacterAppearance(gender, skin)
    skin = type(skin) == 'table' and skin or {}
    if not LoadFreemodeModel(gender) then
        -- Last-resort visual recovery: keep the current ped visible and restore
        -- its default components rather than applying clothing natives to an invalid model.
        local currentPed = PlayerPedId()
        if currentPed and currentPed ~= 0 and DoesEntityExist(currentPed) then
            SetPedDefaultComponentVariation(currentPed)
            SetEntityVisible(currentPed, true, false)
            ResetEntityAlpha(currentPed)
