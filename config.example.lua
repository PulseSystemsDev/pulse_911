-- PulseMDT pulse_911 example configuration.
-- The included config.lua is ready to run. Copy this file over config.lua only
-- when you want the documented defaults as a starting point for customization.
-- Keep the resource folder named exactly pulse_911.
--
-- This add-on never stores PulseMDT credentials. The required pulsemdt core
-- resource reads its API key and Discord guild ID from server-only convars.
-- Put these in server.cfg with set, never setr, because setr replicates values
-- to clients:
-- set pulsemdt_api_key "your-api-key-here"
-- set pulsemdt_guild_id "your-discord-guild-id-here"
--
-- OneSync is recommended so call coordinates can be read authoritatively on
-- the server. Without server-side state awareness, pulse_911 falls back to
-- bounded client coordinates:
-- set onesync on
--
-- Start resources in this order in server.cfg. pulse_notify is optional:
-- ensure pulsemdt
-- ensure pulse_notify
-- ensure pulse_911

Config = {}

-- Emergency command without a leading slash, CAD label, and dispatch priority.
-- Priorities are clamped to the database-safe range 1 through 127. Lower values
-- sort ahead of higher values in dispatch.
Config.Emergency = {
    command  = '911',
    label    = '911 Call',
    priority = 1,
}

-- Non-emergency command without a leading slash, CAD label, and priority.
Config.NonEmergency = {
    command  = '311',
    label    = '311 Call',
    priority = 4,
}

-- Local fallback for anonymous calling. The PulseMDT Scripts dashboard can
-- override this setting. The server sends the effective setting to the form
-- and rejects an anonymous submission if the setting changes before delivery.
Config.AllowAnonymous = true

-- Local per-player cooldown in seconds. The dashboard can override this value.
-- Effective cooldowns are clamped from 0 through 3600 seconds. A stable FiveM
-- license identifier is used when available, so reconnecting does not bypass it.
Config.Cooldown = 30

-- Maximum Unicode characters in a call description. Runtime values are clamped
-- from 1 through 4000 and the NUI textarea receives the effective value.
Config.MaxLength = 300

-- Temporary dispatch blip shown to available on-duty officers.
-- duration is measured in seconds.
Config.Blip = {
    enabled  = true,
    sprite   = 280,
    color    = 1,
    scale    = 1.1,
    duration = 90,
}
