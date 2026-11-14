    -- Even a partially saved outfit must never leave a component missing:
    -- validate every saved drawable/texture and fill absent clothing slots.
    for component = 0, 11 do
        local saved = type(skin.components) == 'table'
            and (skin.components[tostring(component)] or skin.components[component]) or nil
        if type(saved) == 'table' then
            SetSafeComponent(ped, component, saved.drawable, saved.texture)
        elseif safeDefaults[component] then
            SetSafeComponent(ped, component, safeDefaults[component][1], safeDefaults[component][2])
        end
    end

    -- Props are optional. Invalid or missing saved props are cleared safely.
    for prop = 0, 7 do
        local saved = type(skin.props) == 'table'
            and (skin.props[tostring(prop)] or skin.props[prop]) or nil
        if type(saved) == 'table' then
            local drawable = tonumber(saved.drawable) or -1
            local texture = tonumber(saved.texture) or 0
            local propCount = GetNumberOfPedPropDrawableVariations(ped, prop) or 0
            if drawable < 0 or drawable >= propCount then
                ClearPedProp(ped, prop)
            else
