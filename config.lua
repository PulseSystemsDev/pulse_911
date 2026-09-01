Config = {}

Config.Emergency = {
    command  = '911',
    label    = '911 Call',
    priority = 1,
}

Config.NonEmergency = {
    command  = '311',
    label    = '311 Call',
    priority = 4,
}

Config.AllowAnonymous = true

Config.Cooldown = 30

Config.MaxLength = 300

Config.Blip = {
    enabled  = true,
    sprite   = 280,
    color    = 1,
    scale    = 1.1,
    duration = 90,
}
