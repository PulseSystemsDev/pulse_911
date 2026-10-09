# pulse_911

`pulse_911` adds civilian 911 and 311 calls to PulseMDT. Calls appear in the live CAD, available on-duty units receive a local alert, and validated call coordinates can create a temporary map blip.

This resource is for fictional FiveM roleplay only. It is not an emergency service and must not be used to contact real emergency responders.

## Requirements

- A configured [PulseMDT](https://pulsemdt.com/) `pulsemdt` core resource
- OneSync recommended for server-authoritative caller coordinates
- `pulse_notify` optional for styled notifications; native GTA notifications are used when it is absent

The resource is standalone and does not require ESX, QBCore, or Qbox.

## Installation

1. Put this repository in your server resources directory with the exact folder name `pulse_911`.
2. Configure the required `pulsemdt` core resource and generate its API key from the PulseMDT administration page.
3. Keep the included comment-free `config.lua`, or copy `config.example.lua` over it and edit the values.
4. Add the following to `server.cfg`, replacing the two credential placeholders:

```cfg
set pulsemdt_api_key "your-api-key-here"
set pulsemdt_guild_id "your-discord-guild-id-here"
set onesync on

ensure pulsemdt
ensure pulse_notify
ensure pulse_911
```

Use `set`, not `setr`, for the PulseMDT credentials. `setr` exposes a convar to clients. Remove `ensure pulse_notify` if the optional notification resource is not installed. The `pulsemdt` core must start before `pulse_911`.

## Usage

- `/911` opens the emergency description form.
- `/911 <description>` places an identified emergency call immediately.
- `/311` opens the non-emergency description form.
- `/311 <description>` places an identified non-emergency call immediately.
- `/911assign <call-number>` assigns your authorized, on-duty dispatch unit to an active call (for example, `/911assign 6`). Existing assigned units are preserved.

Successful connected call submissions show the CAD reference number in the caller confirmation and on-duty dispatch alert. When the CAD is offline, queued calls do not have a reference number until synchronized; they cannot be assigned by reference yet.

The form opens directly on the requested call type. Its Back button allows the caller to change between emergency and non-emergency before submitting.

## Configuration

The documented defaults are in `config.example.lua`.

| Setting | Purpose | Runtime bounds |
| --- | --- | --- |
| `Config.Emergency.command` | Emergency chat command without `/` | FiveM command name |
| `Config.Emergency.label` | Emergency label stored in CAD | 64 characters |
| `Config.Emergency.priority` | Emergency dispatch priority | 1-127 |
| `Config.NonEmergency.command` | Non-emergency chat command without `/` | FiveM command name |
| `Config.NonEmergency.label` | Non-emergency label stored in CAD | 64 characters |
| `Config.NonEmergency.priority` | Non-emergency dispatch priority | 1-127 |
| `Config.AllowAnonymous` | Local anonymity fallback | Dashboard setting can override it |
| `Config.Cooldown` | Local per-player cooldown in seconds | 0-3600; dashboard can override it |
| `Config.MaxLength` | Maximum call-description length | 1-4000 Unicode characters |
| `Config.Blip.enabled` | Enables dispatch blips | Boolean |
| `Config.Blip.sprite` | FiveM blip sprite ID | Numeric |
| `Config.Blip.color` | FiveM blip color ID | Numeric |
| `Config.Blip.scale` | Blip display scale | Numeric |
| `Config.Blip.duration` | Seconds before a blip is removed | At least 1 second |

Lower priority values sort ahead of higher values in PulseMDT dispatch. The Scripts page in PulseMDT controls the effective cooldown and anonymous-call policy without requiring a resource restart.

## Privacy and validation

An identified call sends the caller's current FiveM player name and linked Discord identifier to PulseMDT. An anonymous call omits both and is marked Anonymous. Every call still includes the caller's in-game location and validated coordinates when available so dispatch can respond.

The server is authoritative about whether anonymous calls are allowed. It sends the effective policy to the form when it opens and checks it again on submission. If the policy changes in between, the anonymous call is rejected and the caller is never silently identified.

Cooldown and in-flight state use the player's stable FiveM license identifier when available. Reconnecting does not clear a valid cooldown. Client call types, text fields, priorities, and coordinates are validated before reaching the CAD.

With OneSync enabled, the server prefers its own player coordinates. If server-side entity state is unavailable, bounded finite client coordinates are used as a fallback. A call without valid coordinates can still be recorded, but it will not create a map blip.

## Troubleshooting

### The resource will not start

Confirm the folder is named `pulse_911`, `fxmanifest.lua` is at its root, and `pulsemdt` starts first. Check the server console for a missing `pulsemdt` dependency.

### /911assign says you cannot assign a call

Make sure the player is on duty in PulseMDT, has a linked Discord account and a police, fire, EMS, or dispatch role, and is in an available or busy duty status. Confirm the call number is still active. This command also requires a PulseMDT web version that implements the authenticated `/api/fivem/[guildId]/cad/[id]/assign` endpoint.

### Calls report that dispatch is unavailable

Verify `pulsemdt_api_key` and `pulsemdt_guild_id` are set in `server.cfg` with `set`, confirm the PulseMDT dashboard shows the server online, and allow outbound HTTPS traffic from FXServer.

### Calls are saved while dispatch is offline

The PulseMDT core queues the CAD write for synchronization. Available in-game units are still alerted locally when the write is queued.

### No officers receive an alert

Officers must be on duty, have an eligible public-safety role, and have an available status in PulseMDT. Start `pulse_notify` before this resource for styled alerts, or rely on the built-in GTA fallback.

### Blips are missing or inaccurate

Enable OneSync with `set onesync on`, verify `Config.Blip.enabled`, and confirm the caller has spawned before placing the call. Without server-side state awareness, the resource can only use validated client coordinates.

### The anonymous option is missing

Check the effective `pulse_911` anonymous-call setting on the PulseMDT Scripts page. Dashboard-managed settings override the local fallback in `config.lua`.

## Support

See the [PulseMDT documentation](https://docs.pulsesystems.dev/pulsemdt) for core setup, Discord permissions, API credentials, and server connectivity.
