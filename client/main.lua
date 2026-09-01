local function notify(msg)
    local ok = pcall(function() exports.pulse_notify:Notify(msg) end)
    if ok then return end
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(msg)
    DrawNotification(false, true)
end

local function currentLocation()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local streetHash, crossHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local text = GetStreetNameFromHashKey(streetHash)
    if text == nil or text == '' then text = 'Unknown' end
    if crossHash and crossHash ~= 0 then
        local cross = GetStreetNameFromHashKey(crossHash)
        if cross and cross ~= '' then text = text .. ' & ' .. cross end
    end
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if zone and zone ~= '' and zone ~= 'NULL' then text = text .. ', ' .. zone end
    return text, coords
end

local function submitCall(kind, description, anonymous)
    local location, coords = currentLocation()
    TriggerServerEvent('pulse_911:submit', {
        kind = kind,
        description = description,
        anonymous = anonymous or false,
        location = location,
        lat = coords.y,
        lng = coords.x,
    })
end

local function openForm(data)
    if type(data) ~= 'table' then return end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        kind = data.kind,
        labelEmergency = data.labelEmergency,
        labelNonEmergency = data.labelNonEmergency,
        prefill = data.prefill or '',
        allowAnonymous = data.allowAnonymous == true,
        maxLength = data.maxLength,
    })
end

local function registerCall(command, kind)
    RegisterCommand(command, function(_, args)
        local text = table.concat(args, ' ')
        if text ~= '' then
            submitCall(kind, text, false)
        else
            TriggerServerEvent('pulse_911:requestForm', kind)
        end
    end, false)
end

registerCall(Config.Emergency.command, 'emergency')
registerCall(Config.NonEmergency.command, 'non_emergency')

RegisterNUICallback('submit', function(data, cb)
    if type(data) == 'table' and type(data.description) == 'string' and data.description:match('%S') then
        SetNuiFocus(false, false)
        submitCall(data.kind, data.description, data.anonymous == true)
    end
    cb({})
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNetEvent('pulse_911:result', function(res)
    if not res then return end
    local prefix = res.ok and '~g~PulseMDT~s~ ' or '~r~PulseMDT~s~ '
    notify(prefix .. (res.message or ''))
end)

RegisterNetEvent('pulse_911:openForm', function(data)
    openForm(data)
end)

RegisterNetEvent('pulse_911:dispatchAlert', function(call)
    if not call then return end
    local head = call.emergency and '~r~911 DISPATCH~s~' or '~y~311 DISPATCH~s~'
    notify(('%s\n%s\n~b~%s~s~'):format(head, call.description or '', call.location or 'Unknown'))

    if Config.Blip and Config.Blip.enabled and type(call.lat) == 'number' and type(call.lng) == 'number' then
        local blip = AddBlipForCoord(call.lng + 0.0, call.lat + 0.0, 30.0)
        SetBlipSprite(blip, tonumber(Config.Blip.sprite) or 280)
        SetBlipColour(blip, tonumber(Config.Blip.color) or 1)
        SetBlipScale(blip, tonumber(Config.Blip.scale) or 1.1)
        SetBlipAsShortRange(blip, false)
        if call.emergency then SetBlipFlashes(blip, true) end
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(call.call_type or 'Dispatch')
        EndTextCommandSetBlipName(blip)
        SetTimeout(math.max(1, tonumber(Config.Blip.duration) or 90) * 1000, function()
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetNuiFocus(false, false)
    end
end)
