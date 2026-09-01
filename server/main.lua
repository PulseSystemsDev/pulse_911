local playerStates = {}
local requestSequence = 0
local inFlightTtl = 120
local stateGrace = 300
local maxCoordinate = 20000.0

local RCFG = { enabled = true, settings = {} }

local function refreshRemote()
    local ok, config = pcall(function()
        return exports.pulsemdt:GetScriptConfig('pulse_911')
    end)
    if ok and type(config) == 'table' then
        RCFG = {
            enabled = config.enabled ~= false,
            settings = type(config.settings) == 'table' and config.settings or {},
        }
    end
end

AddEventHandler('pulsemdt:scriptsRefreshed', refreshRemote)

CreateThread(function()
    Wait(0)
    refreshRemote()
    Wait(4000)
    refreshRemote()
end)

local function setting(key, fallback)
    local value = RCFG.settings and RCFG.settings[key]
    if value == nil then return fallback end
    return value
end

local function isFinite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function clampedNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not isFinite(value) then return fallback end
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function truncateUtf8(value, maxCharacters)
    local length = utf8.len(value)
    if not length then return nil end
    if length <= maxCharacters then return value end
    local boundary = utf8.offset(value, maxCharacters + 1)
    if not boundary then return value end
    return value:sub(1, boundary - 1)
end

local function cleanText(value, maxCharacters, multiline)
    if type(value) ~= 'string' then return nil end
    if multiline then
        value = value:gsub('\r\n', '\n'):gsub('\r', '\n')
        value = value:gsub('[%z\1-\8\11\12\14-\31\127]', '')
    else
        value = value:gsub('%c', ' '):gsub('%s+', ' ')
    end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    value = truncateUtf8(value, maxCharacters)
    if not value then return nil end
    return value:gsub('^%s+', ''):gsub('%s+$', '')
end

local function maxDescriptionLength()
    return math.floor(clampedNumber(Config.MaxLength, 1, 4000, 300))
end

local function cooldownSeconds()
    return math.floor(clampedNumber(setting('cooldownSeconds', Config.Cooldown), 0, 3600, 30))
end

local function anonymityAllowed()
    return setting('allowAnonymous', Config.AllowAnonymous) == true
end

local function kindDetails(name)
    local raw
    local fallbackLabel
    local fallbackPriority
    local emergency

    if name == 'emergency' then
        raw = type(Config.Emergency) == 'table' and Config.Emergency or {}
        fallbackLabel = '911 Call'
        fallbackPriority = 1
        emergency = true
    elseif name == 'non_emergency' then
        raw = type(Config.NonEmergency) == 'table' and Config.NonEmergency or {}
        fallbackLabel = '311 Call'
        fallbackPriority = 4
        emergency = false
    else
        return nil
    end

    local label = cleanText(raw.label, 64, false)
    if not label or label == '' then label = fallbackLabel end

    return {
        name = name,
        label = label,
        priority = math.floor(clampedNumber(raw.priority, 1, 127, fallbackPriority)),
        emergency = emergency,
    }
end

local function identifierByPrefix(src, prefix)
    local ok, identifiers = pcall(GetPlayerIdentifiers, src)
    if not ok or type(identifiers) ~= 'table' then return nil end
    for _, identifier in ipairs(identifiers) do
        if type(identifier) == 'string' and identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end
    return nil
end

local function playerKey(src)
    return identifierByPrefix(src, 'license:')
        or identifierByPrefix(src, 'license2:')
        or identifierByPrefix(src, 'fivem:')
        or identifierByPrefix(src, 'discord:')
        or ('source:' .. tostring(src))
end

local function getDiscordId(src)
    local identifier = identifierByPrefix(src, 'discord:')
    local value = identifier and identifier:sub(9) or nil
    if value and value:match('^%d+$') then return value end
    return nil
end

local function isSamePlayer(src, key)
    return GetPlayerName(src) ~= nil and playerKey(src) == key
end

local function respond(src, key, payload)
    if isSamePlayer(src, key) then
        TriggerClientEvent('pulse_911:result', src, payload)
    end
end

local function touchState(state, now)
    state.expiresAt = math.max(
        state.cooldownUntil or 0,
        state.inFlightUntil or 0,
        now
    ) + stateGrace
end

local function stateFor(key, now)
    local state = playerStates[key]
    if state
        and (state.cooldownUntil or 0) <= now
        and (state.inFlightUntil or 0) <= now
        and (state.expiresAt or 0) <= now then
        playerStates[key] = nil
        state = nil
    end
    if not state then
        state = {
            cooldownUntil = 0,
            inFlightUntil = 0,
            expiresAt = now + stateGrace,
        }
        playerStates[key] = state
    end
    return state
end

local function beginRequest(key, cooldown)
    local now = os.time()
    local state = stateFor(key, now)

    if (state.inFlightUntil or 0) > now then
        return nil, 'A call from you is already being placed.'
    end

    if (state.cooldownUntil or 0) > now then
        local remaining = math.max(1, state.cooldownUntil - now)
        return nil, ('Please wait %d seconds before calling again.'):format(remaining)
    end

    requestSequence = requestSequence + 1
    local token = requestSequence
    state.inFlightToken = token
    state.inFlightUntil = now + inFlightTtl
    state.cooldownUntil = now + cooldown
    touchState(state, now)
    return token
end

local function finishRequest(key, token, accepted)
    local state = playerStates[key]
    if not state or state.inFlightToken ~= token then return end

    state.inFlightToken = nil
    state.inFlightUntil = 0

    if not accepted then
        playerStates[key] = nil
        return
    end

    local now = os.time()
    if (state.cooldownUntil or 0) <= now then
        playerStates[key] = nil
        return
    end
    touchState(state, now)
end

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for key, state in pairs(playerStates) do
            if (state.cooldownUntil or 0) <= now
                and (state.inFlightUntil or 0) <= now
                and (state.expiresAt or 0) <= now then
                playerStates[key] = nil
            end
        end
    end
end)

local function validCoordinates(x, y, z)
    return isFinite(x)
        and isFinite(y)
        and isFinite(z)
        and math.abs(x) <= maxCoordinate
        and math.abs(y) <= maxCoordinate
        and math.abs(z) <= maxCoordinate
end

local function resolveCoordinates(src, data)
    local okPed, ped = pcall(GetPlayerPed, src)
    if okPed and type(ped) == 'number' and ped > 0 then
        local okCoords, coords = pcall(GetEntityCoords, ped)
        if okCoords and coords then
            local okValues, x, y, z = pcall(function()
                return coords.x + 0.0, coords.y + 0.0, coords.z + 0.0
            end)
            if okValues
                and validCoordinates(x, y, z)
                and math.abs(x) + math.abs(y) + math.abs(z) > 0.001 then
                return y, x
            end
        end
    end

    local lat = data.lat
    local lng = data.lng
    if validCoordinates(lng, lat, 0.0) then
        return lat, lng
    end
    return nil, nil
end

local function alertOfficers(call)
    local ok, officers = pcall(function()
        return exports.pulsemdt:GetAvailableOfficers()
    end)
    if not ok or type(officers) ~= 'table' then return end
    for _, src in ipairs(officers) do
        TriggerClientEvent('pulse_911:dispatchAlert', src, call)
    end
end

RegisterNetEvent('pulse_911:requestForm', function(requestedKind)
    local src = source
    local key = playerKey(src)
    local kind = kindDetails(requestedKind)

    if not kind then
        respond(src, key, { ok = false, message = 'That call type is not available.' })
        return
    end

    if not RCFG.enabled then
        respond(src, key, { ok = false, message = '911 calls are disabled on this server.' })
        return
    end

    local emergency = kindDetails('emergency')
    local nonEmergency = kindDetails('non_emergency')
    if isSamePlayer(src, key) then
        TriggerClientEvent('pulse_911:openForm', src, {
            kind = kind.name,
            labelEmergency = emergency.label,
            labelNonEmergency = nonEmergency.label,
            prefill = '',
            allowAnonymous = anonymityAllowed(),
            maxLength = maxDescriptionLength(),
        })
    end
end)

RegisterNetEvent('pulse_911:submit', function(data)
    local src = source
    local key = playerKey(src)

    if type(data) ~= 'table' then
        respond(src, key, { ok = false, message = 'Invalid call data.' })
        return
    end

    if not RCFG.enabled then
        respond(src, key, { ok = false, message = '911 calls are disabled on this server.' })
        return
    end

    local kind = kindDetails(data.kind)
    if not kind then
        respond(src, key, { ok = false, message = 'That call type is not available.' })
        return
    end

    local description = cleanText(data.description, maxDescriptionLength(), true)
    if not description or description == '' then
        respond(src, key, { ok = false, message = 'You must describe the situation.' })
        return
    end

    if data.anonymous ~= nil and type(data.anonymous) ~= 'boolean' then
        respond(src, key, { ok = false, message = 'Invalid anonymity setting.' })
        return
    end

    local anonymous = data.anonymous == true
    if anonymous and not anonymityAllowed() then
        respond(src, key, {
            ok = false,
            message = 'Anonymous calls are no longer allowed. Submit again without anonymity.',
        })
        return
    end

    local location = cleanText(data.location, 256, false)
    if not location or location == '' then location = 'Unknown' end

    local callerName = anonymous and 'Anonymous' or cleanText(GetPlayerName(src), 64, false)
    if not callerName or callerName == '' then callerName = 'Unknown Caller' end
    local discordId
    if not anonymous then
        discordId = getDiscordId(src)
    end
    local lat, lng = resolveCoordinates(src, data)
    local cooldown = cooldownSeconds()
    local token, rejection = beginRequest(key, cooldown)

    if not token then
        respond(src, key, { ok = false, message = rejection })
        return
    end

    local body = {
        call_type = kind.label,
        location = location,
        description = anonymous and ('(Anonymous) ' .. description) or (callerName .. ': ' .. description),
        priority = kind.priority,
        discordId = discordId,
        lat = lat,
        lng = lng,
    }

    local alert = {
        call_type = kind.label,
        location = location,
        description = description,
        caller = callerName,
        emergency = kind.emergency,
        lat = lat,
        lng = lng,
    }

    local completed = false
    local dispatched = pcall(function()
        exports.pulsemdt:ApiWrite('POST', '/cad', body, function(code)
            if completed then return end
            completed = true

            local status = tonumber(code)
            local queued = status == 0
            local accepted = status and status >= 200 and status < 300

            if accepted or queued then
                finishRequest(key, token, true)
                alertOfficers(alert)
                if queued then
                    respond(src, key, {
                        ok = true,
                        message = 'Dispatch is offline. Your call was saved and available units were notified.',
                    })
                else
                    respond(src, key, {
                        ok = true,
                        message = kind.label .. ' received. Units are being notified.',
                    })
                end
                return
            end

            finishRequest(key, token, false)
            respond(src, key, {
                ok = false,
                message = 'Your call could not be placed. Please try again.',
            })
        end)
    end)

    if not dispatched and not completed then
        completed = true
        finishRequest(key, token, false)
        respond(src, key, {
            ok = false,
            message = 'Dispatch is unavailable right now.',
        })
    end
end)
