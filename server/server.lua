if Config.FrameWork == "esx" then
    ESX = exports['es_extended']:getSharedObject()
elseif Config.FrameWork == "qb" then
    QBCore = exports['qb-core']:GetCoreObject()
end

lib.locale()

-- -------------------------------------------------------------------
--  In-memory table reflecting the DB: key = requestId (auto-increment), value = data
-- -------------------------------------------------------------------
local robberyRequests = {}

-- -------------------------------------------------------------------
--  LOAD ROBBERY REQUESTS FROM DATABASE
--  This will populate the `robberyRequests` table with existing requests
-- -------------------------------------------------------------------
MySQL.ready(function()
    local filas = MySQL.query.await('SELECT * FROM robbery_requests')
    for _, row in ipairs(filas) do
        robberyRequests[row.id] = {
            thiefIdentifier     = row.thief_identifier,
            thiefName           = row.thief_name,
            status              = row.status,
            time                = row.timestamp,
            decidedByIdentifier = row.decided_by_identifier,
            decidedByName       = row.decided_by_name,
            robberyType         = row.robbery_type,
            serverId            = nil
        }
    end
end)

-- -------------------------------------------------------------------
--  AUXILIAR FUNCTION
-- -------------------------------------------------------------------
local function GetPlayerPersistentIdentifier(playerId)
    local ids = GetPlayerIdentifiers(playerId)
    if ids and #ids > 0 then
        return ids[1]
    end
    return nil
end

-- -------------------------------------------------------------------
--  2) EVENT
-- -------------------------------------------------------------------
local function CountCopsByJobs(jobs)
    local policeCount = 0

    for _, job in ipairs(jobs) do
        if Config.Framework == 'esx' or Config.Framework == 'newesx' then
            if GetResourceState("origen_police") ~= "missing" then
                local playersReady = exports['origen_police']:GetPlayersReadyByJob(job, true)
                for _ in pairs(playersReady) do
                    policeCount = policeCount + 1
                end
            else
                local playersInDuty = ESX.GetExtendedPlayers("job", job)
                policeCount = policeCount + #playersInDuty
            end
        else
            if GetResourceState("origen_police") ~= "missing" then
                local playersReady = exports['origen_police']:GetPlayersReadyByJob(job, true)
                for _ in pairs(playersReady) do
                    policeCount = policeCount + 1
                end
            else
                policeCount = policeCount + #(QBCore.Functions.GetPlayersOnDuty(job))
            end
        end
    end

    return policeCount
end

lib.callback.register('muhaddil_robbery:getRobberies', function(source)
    local policeJobs = Config.policejobs
    local policeCount = CountCopsByJobs(policeJobs)

    local robberyList = {}
    for _, robbery in ipairs(Config.Robberies) do
        local enabled = (policeCount >= robbery.minimumPolice)
        table.insert(robberyList, {
            label = robbery.name .. (enabled and "" or " [NO DISPONIBLE]"),
            value = robbery.name,
            disabled = not enabled
        })
    end

    return robberyList
end)

RegisterNetEvent('muhaddil_robbery:requestRobbery', function(robberyName) 
    local src = source
    if type(robberyName) ~= "string" then
        TriggerClientEvent('muhaddil_insurances:Notify', src, locale('robbery_error'), locale('robbery_invalid'), 5000, "error")
        return
    end

    local chosen = nil
    for _, roboData in ipairs(Config.Robberies) do
        if roboData.name == robberyName then
            chosen = roboData
            break
        end
    end

    if not chosen then
        TriggerClientEvent('muhaddil_insurances:Notify', src, locale('robbery_error'), locale('robbery_not_found'), 5000, "error")
        return
    end

    local persistentId = GetPlayerPersistentIdentifier(src)
    if not persistentId then
        TriggerClientEvent('muhaddil_insurances:Notify', src, locale('robbery_error'), locale('robbery_identifier_not_found'), 5000, "error")
        return
    end

    local now                 = os.time()
    local playerName          = GetPlayerName(src) or "Desconocido"

    local insertId            = MySQL.insert.await([[
        INSERT INTO robbery_requests
            (thief_identifier, thief_name, status, timestamp, robbery_type)
        VALUES
            (?, ?, 'pendiente', ?, ?)
    ]], {
        persistentId,
        playerName,
        now,
        chosen.name
    })

    robberyRequests[insertId] = {
        thiefIdentifier     = persistentId,
        thiefName           = playerName,
        status              = "pendiente",
        time                = now,
        decidedByIdentifier = nil,
        decidedByName       = nil,
        robberyType         = chosen.name,
        serverId            = src
    }

    TriggerClientEvent('muhaddil_insurances:Notify', src, locale('robbery_sent'),
        (locale('robbery_sent_desc')):format(insertId, chosen.name),
        5000, "info")

    local filasParaEliminar = MySQL.query.await([[
        SELECT id
          FROM robbery_requests
         WHERE thief_identifier = ?
         ORDER BY timestamp DESC
         LIMIT 5 OFFSET 5
    ]], { persistentId })

    if #filasParaEliminar > 0 then
        local idsAEliminar = {}
        for _, fila in ipairs(filasParaEliminar) do
            table.insert(idsAEliminar, fila.id)
        end

        MySQL.query('DELETE FROM robbery_requests WHERE id IN (?)', { idsAEliminar })
        for _, idOld in ipairs(idsAEliminar) do
            robberyRequests[idOld] = nil
        end
    end

    SetTimeout(Config.AutoExpire * 60 * 1000, function()
        local req = robberyRequests[insertId]
        if req and req.status == "pendiente" then
            req.status = "rechazado"
            MySQL.query('UPDATE robbery_requests SET status = ? WHERE id = ?', {
                "rechazado",
                insertId
            })
            if req.serverId and GetPlayerName(req.serverId) then
                TriggerClientEvent('muhaddil_insurances:Notify', req.serverId,
                    locale('robbery_auto_rejected'),
                    (locale('robbery_auto_rejected_desc')):format(insertId, req.robberyType),
                    5000, "error")
            end
        end
    end)
end)

-- -------------------------------------------------------------------
--  3) EVENT
--       Parameters:
--         targetRequestId = `id` (Collumn in DB)
--         accepted        = true/false
-- -------------------------------------------------------------------
RegisterNetEvent('muhaddil_robbery:responseFromPolice', function(targetRequestId, accepted)
    local src = source
    local req = robberyRequests[targetRequestId]
    if not req or req.status ~= "pendiente" then
        return
    end

    local policeIdentifier = GetPlayerPersistentIdentifier(src)
    local policeName       = GetPlayerName(src) or "Desconocido"

    if accepted then
        req.status              = "aceptado"
        req.decidedByIdentifier = policeIdentifier
        req.decidedByName       = policeName

        MySQL.query([[
            UPDATE robbery_requests
               SET status = ?, decided_by_identifier = ?, decided_by_name = ?
             WHERE id = ?
        ]], {
            "aceptado",
            policeIdentifier,
            policeName,
            targetRequestId
        })

        if req.serverId and GetPlayerName(req.serverId) then
            TriggerClientEvent('muhaddil_insurances:Notify', req.serverId,
                "Aprobado",
                "Tu solicitud #" .. targetRequestId .. " fue ACEPTADA por " .. policeName .. ".",
                5000, "success")
        end
    else
        req.status              = "rechazado"
        req.decidedByIdentifier = policeIdentifier
        req.decidedByName       = policeName

        MySQL.query([[
            UPDATE robbery_requests
               SET status = ?, decided_by_identifier = ?, decided_by_name = ?
             WHERE id = ?
        ]], {
            "rechazado",
            policeIdentifier,
            policeName,
            targetRequestId
        })

        if req.serverId and GetPlayerName(req.serverId) then
            TriggerClientEvent('muhaddil_insurances:Notify', req.serverId,
                "Rechazado",
                "Tu solicitud #" .. targetRequestId .. " fue RECHAZADA por " .. policeName .. ".",
                5000, "error")
        end

        TriggerClientEvent('muhaddil_insurances:Notify', src,
            "Rechazaste",
            "Has rechazado la solicitud #" .. targetRequestId .. ".",
            5000, "info")
    end
end)

-- -------------------------------------------------------------------
--  4) EVENT
-- -------------------------------------------------------------------
RegisterNetEvent('muhaddil_robbery:getAllRobberies', function()
    local src     = source
    local jobName = nil

    if Config.FrameWork == "esx" then
        local xPlayer = ESX.GetPlayerFromId(src)
        jobName = xPlayer and xPlayer.getJob().name
    elseif Config.FrameWork == "qb" then
        local xPlayer = QBCore.Functions.GetPlayer(src)
        jobName = xPlayer and xPlayer.PlayerData.job.name
    end

    if jobName ~= "police" then
        return
    end

    local listaTemporal = {}
    for requestId, data in pairs(robberyRequests) do
        table.insert(listaTemporal, {
            id              = requestId,
            thiefIdentifier = data.thiefIdentifier,
            thiefName       = data.thiefName,
            status          = data.status,
            timestamp       = data.time,
            decidedByName   = data.decidedByName,
            robberyType     = data.robberyType
        })
    end

    table.sort(listaTemporal, function(a, b)
        return a.timestamp > b.timestamp
    end)

    local listaFinal = {}
    for i = 1, math.min(5, #listaTemporal) do
        local entry = listaTemporal[i]
        entry.timeFormatted = os.date("%Y-%m-%d %H:%M:%S", entry.timestamp)
        table.insert(listaFinal, entry)
    end

    TriggerClientEvent('muhaddil_robbery:showAllRobberies', src, listaFinal)
end)

-- -------------------------------------------------------------------
--  5) EVENT
-- -------------------------------------------------------------------
RegisterNetEvent('muhaddil_robbery:checkRobberyStatus', function()
    local src          = source
    local persistentId = GetPlayerPersistentIdentifier(src)
    if not persistentId then
        TriggerClientEvent('muhaddil_robbery:showRobberyStatus', src, nil)
        return
    end

    local miListaTemp = {}
    for requestId, data in pairs(robberyRequests) do
        if data.thiefIdentifier == persistentId then
            table.insert(miListaTemp, {
                id            = requestId,
                status        = data.status,
                timestamp     = data.time,
                decidedByName = data.decidedByName -- It may be nil if still pending
            })
        end
    end

    table.sort(miListaTemp, function(a, b)
        return a.timestamp > b.timestamp
    end)

    local miListaFinal = {}
    for i = 1, math.min(5, #miListaTemp) do
        local entry = miListaTemp[i]
        entry.timeFormatted = os.date("%Y-%m-%d %H:%M:%S", entry.timestamp)
        table.insert(miListaFinal, entry)
    end

    TriggerClientEvent('muhaddil_robbery:showRobberyStatus', src, miListaFinal)
end)

-- -------------------------------------------------------------------
--  6) EXPORT: Gives the last 5 pending robbery requests
--  (for use in other scripts, e.g., to show in a UI)
-- -------------------------------------------------------------------
function GetPendingRequests()
    local pendientesTemp = {}

    for requestId, data in pairs(robberyRequests) do
        if data.status == "pendiente" then
            table.insert(pendientesTemp, {
                id              = requestId,
                thiefIdentifier = data.thiefIdentifier,
                thiefName       = data.thiefName,
                timestamp       = data.time
            })
        end
    end

    table.sort(pendientesTemp, function(a, b)
        return a.timestamp > b.timestamp
    end)

    local pendientesFinal = {}
    for i = 1, math.min(5, #pendientesTemp) do
        local entry = pendientesTemp[i]
        entry.timeFormatted = os.date("%Y-%m-%d %H:%M:%S", entry.timestamp)
        table.insert(pendientesFinal, entry)
    end

    return pendientesFinal
end

exports('GetPendingRequests', GetPendingRequests)
