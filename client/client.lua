if Config.FrameWork == "esx" then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.FrameWork == "qb" then
    QBCore = exports['qb-core']:GetCoreObject()
end

lib.locale()

-- -------------------------------------------------------------------
--  Notify Function
-- -------------------------------------------------------------------
local function Notify(msgtitle, msg, time, type2)
    if Config.UseOXNotifications then
        lib.notify({
            title        = msgtitle,
            description  = msg,
            showDuration = true,
            type         = type2,
        })
    else
        if Config.FrameWork == 'qb' then
            QBCore.Functions.Notify(msg, type2, time)
        elseif Config.FrameWork == 'esx' then
            TriggerEvent('esx:showNotification', msg, type2, time)
        end
    end
end

RegisterNetEvent('muhaddil_insurances:Notify')
AddEventHandler('muhaddil_insurances:Notify', function(msgtitle, msg, time, type)
    Notify(msgtitle, msg, time, type)
end)

-- -------------------------------------------------------------------
--  1) /pedirrobo
-- -------------------------------------------------------------------
RegisterCommand('pedirrobo', function()
    lib.callback('muhaddil_robbery:getRobberies', false, function(robberyList)
        local options = {}

        for _, robbery in ipairs(robberyList) do
            table.insert(options, {
                title = robbery.label,
                disabled = robbery.disabled,
                icon = robbery.disabled and 'x' or 'check',
                onSelect = function()
                    if not robbery.disabled then
                        TriggerServerEvent('muhaddil_robbery:requestRobbery', robbery.value)
                    end
                end
            })
        end

        lib.registerContext({
            id = 'pedirrobo_menu',
            title = locale('robbery_menu_title'),
            options = options
        })

        lib.showContext('pedirrobo_menu')
    end)
end)

RegisterNetEvent('muhaddil_robbery:showRobberyList', function(lista)
    if not lista or #lista == 0 then
        Notify(locale('robbery_global_menu_title'), locale('robbery_no_data'), 5000, "error")
        return
    end

    local options = {}
    for _, robo in ipairs(lista) do
        local label = robo.name
        local desc  = locale('robbery_cops', robo.currentCops, robo.minimum)

        if robo.enabled then
            table.insert(options, {
                title       = label,
                description = desc,
                icon        = "exclamation",
                onSelect    = function()
                    TriggerServerEvent('muhaddil_robbery:requestRobbery', robo.name)
                    lib.hideContext()
                end
            })
        else
            table.insert(options, {
                title       = label .. locale('robbery_disabled'),
                description = desc,
                icon        = "lock"
            })
        end
    end

    lib.registerContext({
        id      = 'robbery_types_menu',
        title   = locale('robbery_types_menu_title'),
        options = options
    })

    lib.showContext('robbery_types_menu')
end)

-- -------------------------------------------------------------------
--  2) /estadoRobo
-- -------------------------------------------------------------------
RegisterCommand('estadoRobo', function()
    TriggerServerEvent('muhaddil_robbery:checkRobberyStatus')
end)

RegisterNetEvent('muhaddil_robbery:showRobberyStatus', function(listado)
    -- "listado" is an array of up to 5 records:
    -- { id, status, timeFormatted, decidedByName }

    if not listado or #listado == 0 then
        Notify("Estado de Robos", "No tienes solicitudes registradas.", 5000, "error")
        return
    end

    local opciones = {}
    for _, entry in ipairs(listado) do
        local estadoTexto = entry.status == "pendiente" and locale('robbery_status_pending')
            or entry.status == "aceptado" and locale('robbery_status_accepted')
            or locale('robbery_status_rejected')
        local descripcion = locale('robbery_id', entry.id) .. "\n" .. locale('robbery_date', entry.timeFormatted)
        if entry.decidedByName then
            descripcion = descripcion .. "\n" .. locale('robbery_decided_by', entry.decidedByName)
        end

        table.insert(opciones, {
            title       = "[" .. string.upper(entry.status) .. "]",
            description = descripcion,
            icon        = entry.status == "aceptado" and "check"
                or (entry.status == "rechazado" and "xmark" or "clock")
        })
    end

    lib.registerContext({
        id      = 'robbery_status_menu',
        title   = 'Tu Historial (máx. 5)',
        options = opciones
    })
    lib.showContext('robbery_status_menu')
end)

-- -------------------------------------------------------------------
--  3) /verrobos
-- -------------------------------------------------------------------
RegisterCommand('verrobos', function()
    TriggerServerEvent('muhaddil_robbery:getAllRobberies')
end)

RegisterNetEvent('muhaddil_robbery:showAllRobberies', function(listado)
    -- "listado" is an array of up to 5 records:
    -- { id, thiefIdentifier, thiefName, status, timeFormatted, decidedByName }

    if not listado or #listado == 0 then
        Notify("Historial de Robos", "No hay solicitudes registradas.", 5000, "info")
        return
    end

    local opciones = {}
    for _, entry in ipairs(listado) do
        local labelEstado = "[" .. string.upper(entry.status) .. "]"
        local titulo      = labelEstado .. " " .. entry.thiefName
        local descripcion = locale('robbery_id', entry.id) ..
        "\n" .. locale('robbery_date', entry.timeFormatted) .. "\n" .. locale('robbery_type', entry.robberyType)
        if entry.status ~= "pendiente" and entry.decidedByName then
            descripcion = descripcion .. "\n" .. locale('robbery_decided_by', entry.decidedByName)
        end

        if entry.status == "pendiente" then
            table.insert(opciones, {
                title       = titulo,
                description = descripcion,
                icon        = "exclamation",
                onSelect    = function()
                    lib.registerContext({
                        id      = 'robbery_decision_menu_' .. entry.id,
                        title   = locale('robbery_confirm_title', entry.id, entry.thiefName),
                        options = {
                            {
                                title    = locale('robbery_accept'),
                                icon     = 'check',
                                onSelect = function()
                                    TriggerServerEvent('muhaddil_robbery:responseFromPolice', entry.id, true)
                                    TriggerServerEvent('muhaddil_robbery:getAllRobberies')
                                end
                            },
                            {
                                title    = locale('robbery_reject'),
                                icon     = 'xmark',
                                onSelect = function()
                                    TriggerServerEvent('muhaddil_robbery:responseFromPolice', entry.id, false)
                                    TriggerServerEvent('muhaddil_robbery:getAllRobberies')
                                end
                            }
                        }
                    })
                    lib.showContext('robbery_decision_menu_' .. entry.id)
                end
            })
        else
            table.insert(opciones, {
                title       = titulo,
                description = descripcion,
                icon        = entry.status == "aceptado" and "check" or "xmark"
            })
        end
    end

    lib.registerContext({
        id      = 'all_robberies_menu',
        title   = locale('robbery_global_menu_title'),
        options = opciones
    })
    lib.showContext('all_robberies_menu')
end)

-- -------------------------------------------------------------------
--  Open Robberies Menu With NUI
-- -------------------------------------------------------------------
RegisterNUICallback('openRobberiesMenu', function(data, cb)
    TriggerServerEvent('muhaddil_robbery:getAllRobberies')
    cb('ok')
end)

-- Example
-- $.post('https://muhaddil_robberydispo/openRobberiesMenu', JSON.stringify({}));

RegisterNUICallback('openAksRobberiesMenu', function(data, cb)
    lib.callback('muhaddil_robbery:getRobberies', false, function(robberyList)
        local options = {}

        for _, robbery in ipairs(robberyList) do
            table.insert(options, {
                title = robbery.label,
                disabled = robbery.disabled,
                icon = robbery.disabled and 'x' or 'check',
                onSelect = function()
                    if not robbery.disabled then
                        TriggerServerEvent('muhaddil_robbery:requestRobbery', robbery.value)
                    end
                end
            })
        end

        lib.registerContext({
            id = 'pedirrobo_menu',
            title = locale('robbery_menu_title'),
            options = options
        })

        lib.showContext('pedirrobo_menu')
    end)

    cb('ok')
end)

-- Example
-- $.post('https://muhaddil_robberydispo/openAksRobberiesMenu', JSON.stringify({}));
