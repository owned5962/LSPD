Config = {}

Config.CooldownMs = 45000
Config.DetectionRange = 120.0
Config.ApproachDistance = 3.0
Config.PedModel = 's_m_y_cop_01'
Config.PedSpawnDistance = 28.0
Config.Prison = vector4(1845.3, 2585.9, 45.7, 270.0) -- Pénitencier de Bolingbroke
Config.SurrenderFreezeMs = 30000
Config.AlertLimit = 40

Config.Offences = {
    assault_npc = { label = 'Agression sur un civil', severity = 'Moyenne' },
    assault_player = { label = 'Agression sur une personne', severity = 'Moyenne' },
    murder_npc = { label = 'Homicide sur un civil', severity = 'Critique' },
    murder_player = { label = 'Homicide sur une personne', severity = 'Critique' },
    public_shooting = { label = 'Usage d’une arme à feu en public', severity = 'Élevée' },
    vehicle_theft = { label = 'Vol de véhicule', severity = 'Élevée' },
    pedestrian_collision = { label = 'Collision avec un piéton', severity = 'Moyenne' }
}
