Config = {}

Config.Price = 100
Config.DurationDays = 7
Config.InteractionDistance = 1.0
Config.ServerValidationDistance = 1.5
Config.PedModel = 'a_m_m_business_01'
Config.PedSpawnDistance = 140.0
Config.PedDespawnDistance = 190.0
Config.AreaSize = 500.0
Config.AreaAlphaFree = 0
Config.AreaAlphaOwned = 190
Config.PointBlipSprite = 38
Config.PointBlipScale = 0.65

Config.Colors = {
    { id = 1, name = 'Rouge', hex = '#ef4444' },
    { id = 2, name = 'Vert', hex = '#22c55e' },
    { id = 3, name = 'Bleu', hex = '#3b82f6' },
    { id = 5, name = 'Jaune', hex = '#eab308' },
    { id = 7, name = 'Violet', hex = '#a855f7' },
    { id = 8, name = 'Rose', hex = '#ec4899' },
    { id = 17, name = 'Orange', hex = '#f97316' },
    { id = 18, name = 'Cyan', hex = '#06b6d4' }
}

Config.Sectors = {}
do
    local index = 0
    -- Urban Los Santos grid: 6 columns x 10 rows, 60 individual sectors.
    -- Each square is 500 x 500 GTA map units.
    for row = 0, 9 do
        for column = 0, 5 do
            index = index + 1
            Config.Sectors[#Config.Sectors + 1] = {
                id = ('LS-%02d'):format(index),
                x = -1500.0 + (column * Config.AreaSize) + (Config.AreaSize / 2),
                y = -500.0 + (row * Config.AreaSize) + (Config.AreaSize / 2),
                z = 30.0
            }
        end
    end
end

Config.SectorById = {}
for _, sector in ipairs(Config.Sectors) do
    Config.SectorById[sector.id] = sector
end

Config.ColorById = {}
for _, color in ipairs(Config.Colors) do
    Config.ColorById[color.id] = color
end
