local Races = {}
local AvailableRaces = {}
local LastRaces = {}
local NotFinished = {}
local RaceEditors = {}
local MAX_RACE_NAME_LENGTH = 50
local MAX_CHECKPOINTS = 200
local MAX_COORDINATE = 20000
local MAX_RACE_LAPS = 50
local MAX_PLAUSIBLE_SPEED = 150

---@param value any
---@return boolean
local function isFiniteNumber(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@param value any
---@return boolean
local function isInteger(value)
    return isFiniteNumber(value) and value % 1 == 0
end

---@param value any
---@return vector3?
local function validateCoords(value)
    local valueType = type(value)
    if valueType ~= 'table' and valueType ~= 'vector3' and valueType ~= 'vector4' then return end

    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not isFiniteNumber(x) or not isFiniteNumber(y) or not isFiniteNumber(z) then return end
    if math.abs(x) > MAX_COORDINATE or math.abs(y) > MAX_COORDINATE or math.abs(z) > MAX_COORDINATE then return end
    return vec3(x, y, z)
end

---@param checkpoints any
---@return table? validated
---@return number? distance
local function validateCheckpoints(checkpoints)
    if type(checkpoints) ~= 'table' or #checkpoints < 2 or #checkpoints > MAX_CHECKPOINTS then return end

    local validated = {}
    local distance = 0
    for i = 1, #checkpoints do
        local checkpoint = checkpoints[i]
        if type(checkpoint) ~= 'table' or type(checkpoint.offset) ~= 'table' then return end

        local coords = validateCoords(checkpoint.coords)
        local left = validateCoords(checkpoint.offset.left)
        local right = validateCoords(checkpoint.offset.right)
        if not coords or not left or not right then return end
        if #(left - right) < 1 or #(left - right) > 40 then return end

        validated[i] = {
            coords = coords,
            offset = {
                left = left,
                right = right,
            },
        }
        if i > 1 then
            distance += #(coords - validated[i - 1].coords)
        end
    end
    if distance <= 0 or distance > 1000000 then return end
    return validated, distance
end

-- Functions

local function SecondsToClock(seconds)
    seconds = tonumber(seconds)
    if seconds > 0 then
        local hours = string.format("%02.f", math.floor(seconds / 3600))
        local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
        local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))
        return hours..":"..mins..":"..secs
    end
    return "00:00:00"
end

local function IsWhitelisted(citizenId)
    for _, cid in pairs(Config.WhitelistedCreators) do
        if cid == citizenId then
            return true
        end
    end
    local player = exports.qbx_core:GetPlayerByCitizenId(citizenId)
    if not player then return false end

    local perms = exports.qbx_core:GetPermission(player.PlayerData.source)
    return perms == "admin" or perms == "god"
end

local function IsNameAvailable(raceName)
    for RaceId in pairs(Races) do
        if Races[RaceId].RaceName == raceName then
            return false
        end
    end
    return true
end

local function HasOpenedRace(citizenId)
    for _, v in pairs(AvailableRaces) do
        if v.SetupCitizenId == citizenId then
            return true
        end
    end
    return false
end

local function GetOpenedRaceKey(raceId)
    for k, v in pairs(AvailableRaces) do
        if v.RaceId == raceId then
            return k
        end
    end
end

local function GetCurrentRace(citizenId)
    for raceId in pairs(Races) do
        for cid in pairs(Races[raceId].Racers) do
            if cid == citizenId then
                return raceId
            end
        end
    end
end

local function GetRaceId(name)
    for k, v in pairs(Races) do
        if v.RaceName == name then
            return k
        end
    end
end

local function GenerateRaceId()
    local raceId = "LR-" .. math.random(0, 9999999)
    while Races[raceId] do
        raceId = "LR-" .. math.random(0, 9999999)
    end
    return raceId
end

-- Events

RegisterNetEvent('qb-lapraces:server:FinishPlayer', function(RaceId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player or type(RaceId) ~= 'string' then return end

    local race = Races[RaceId]
    local AvailableKey = GetOpenedRaceKey(RaceId)
    local availableRace = AvailableKey and AvailableRaces[AvailableKey]
    local racer = race and race.Racers[Player.PlayerData.citizenid]
    if not race or not availableRace or not racer or not racer.Finished
        or racer.ResultRecorded or not racer.FinishedAt or not racer.StartedAt then return end

    local TotalTime = math.max(1, math.floor((racer.FinishedAt - racer.StartedAt) / 1000))
    local BestLap = availableRace.Laps < 2 and TotalTime or racer.BestLap or TotalTime
    racer.ResultRecorded = true

    local PlayersFinished = 0
    local AmountOfRacers = 0

    for _, v in pairs(race.Racers) do
        if v.ResultRecorded then
            PlayersFinished += 1
        end
        AmountOfRacers += 1
    end

    LastRaces[RaceId] = LastRaces[RaceId] or {}
    LastRaces[RaceId][#LastRaces[RaceId] + 1] = {
        TotalTime = TotalTime,
        BestLap = BestLap,
        Holder = {
            Player.PlayerData.charinfo.firstname,
            Player.PlayerData.charinfo.lastname
        }
    }

    if race.Records and table.type(race.Records) ~= 'empty' then
        if BestLap < race.Records.Time then
            race.Records = {
                Time = BestLap,
                Holder = {
                    Player.PlayerData.charinfo.firstname,
                    Player.PlayerData.charinfo.lastname
                }
            }
            MySQL.update('UPDATE lapraces SET records = ? WHERE raceid = ?', {json.encode(race.Records), RaceId})
            TriggerClientEvent('qb-phone:client:RaceNotify', src, locale('phonenotif.wonWR', race.RaceName, SecondsToClock(BestLap)))
        end
    else
        race.Records = {
            Time = BestLap,
            Holder = {
                Player.PlayerData.charinfo.firstname,
                Player.PlayerData.charinfo.lastname
            }
        }
        MySQL.update('UPDATE lapraces SET records = ? WHERE raceid = ?', {json.encode(race.Records), RaceId})
        TriggerClientEvent('qb-phone:client:RaceNotify', src, locale('phonenotif.wonWR2', race.RaceName, SecondsToClock(BestLap)))
    end

    availableRace.RaceData = race
    TriggerClientEvent('qb-lapraces:client:PlayerFinishs', -1, RaceId, PlayersFinished, Player)
    if PlayersFinished == AmountOfRacers then
        if NotFinished[RaceId] and table.type(NotFinished[RaceId]) ~= 'empty' then
            for _, v in pairs(NotFinished[RaceId]) do
                LastRaces[RaceId][#LastRaces[RaceId] + 1] = {
                    TotalTime = v.TotalTime,
                    BestLap = v.BestLap,
                    Holder = v.Holder
                }
            end
        end
        race.LastLeaderboard = LastRaces[RaceId]
        race.Racers = {}
        race.Started = false
        race.Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        LastRaces[RaceId] = nil
        NotFinished[RaceId] = nil
    end
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('qb-lapraces:server:CreateLapRace', function(RaceName)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if type(RaceName) ~= 'string' then return end

    RaceName = RaceName:match('^%s*(.-)%s*$')
    if #RaceName < 3 or #RaceName > MAX_RACE_NAME_LENGTH or RaceName:find('%c') then return end
    if not Config.RaceSetupAllowed then return end

    if Player and IsWhitelisted(Player.PlayerData.citizenid) then
        if IsNameAvailable(RaceName) then
            RaceEditors[src] = RaceName
            TriggerClientEvent('qb-lapraces:client:StartRaceEditor', source, RaceName)
        else
            exports.qbx_core:Notify(source, locale('error.namealreadyused'), 'error')
        end
    else
        exports.qbx_core:Notify(source, locale('error.notauthorized', locale('general.createraces')), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:JoinRace', function(RaceData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player or type(RaceData) ~= 'table' or type(RaceData.RaceId) ~= 'string' then return end

    local RaceId = RaceData.RaceId
    local AvailableKey = GetOpenedRaceKey(RaceId)
    local race = Races[RaceId]
    local availableRace = AvailableKey and AvailableRaces[AvailableKey]
    if not race or not availableRace or not race.Waiting or race.Started then return end

    local CurrentRace = GetCurrentRace(Player.PlayerData.citizenid)
    if CurrentRace then return end

    Races[RaceId].Waiting = true
    Races[RaceId].Racers[Player.PlayerData.citizenid] = {
        Checkpoint = 1,
        Lap = 1,
        Finished = false,
    }
    AvailableRaces[AvailableKey].RaceData = Races[RaceId]
    TriggerClientEvent('qb-lapraces:client:JoinRace', src, Races[RaceId], AvailableRaces[AvailableKey].Laps)
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
    local creator = exports.qbx_core:GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId)
    local creatorsource = creator and creator.PlayerData.source
    if creatorsource and creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('qb-phone:client:RaceNotify', creatorsource, locale('phonenotif.joinedrace',string.sub(Player.PlayerData.charinfo.firstname, 1, 1), Player.PlayerData.charinfo.lastname))
    end
end)

RegisterNetEvent('qb-lapraces:server:LeaveRace', function()
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end

    local RaceId = GetCurrentRace(Player.PlayerData.citizenid)
    if not RaceId or not Races[RaceId] then return end

    local AvailableKey = GetOpenedRaceKey(RaceId)
    if not AvailableKey then return end

    local creatorsource = exports.qbx_core:GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId)?.PlayerData.source
    if creatorsource and creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('qb-phone:client:RaceNotify', creatorsource, locale('phonenotif.LeaveRace',string.sub(Player.PlayerData.charinfo.firstname, 1, 1), Player.PlayerData.charinfo.lastname))
    end
    local AmountOfRacers = 0
    for _ in pairs(Races[RaceId].Racers) do
        AmountOfRacers += 1
    end
    if NotFinished[RaceId] then
        NotFinished[RaceId][#NotFinished[RaceId] + 1] = {
            TotalTime = locale('general.DNF'),
            BestLap = locale('general.DNF'),
            Holder = {
                Player.PlayerData.charinfo.firstname,
                Player.PlayerData.charinfo.lastname
            }
        }
    else
        NotFinished[RaceId] = {}
        NotFinished[RaceId][#NotFinished[RaceId] + 1] = {
            TotalTime = locale('general.DNF'),
            BestLap = locale('general.DNF'),
            Holder = {
                Player.PlayerData.charinfo.firstname,
                Player.PlayerData.charinfo.lastname
            }
        }
    end
    Races[RaceId].Racers[Player.PlayerData.citizenid] = nil
    if AmountOfRacers - 1 == 0 then
        if NotFinished and table.type(NotFinished) ~= 'empty' and NotFinished[RaceId] and table.type(NotFinished[RaceId]) ~= 'empty' then
            for _, v in pairs(NotFinished[RaceId]) do
                if LastRaces[RaceId] then
                    LastRaces[RaceId][#LastRaces[RaceId]+1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = v.Holder
                    }
                else
                    LastRaces[RaceId] = {}
                    LastRaces[RaceId][#LastRaces[RaceId] + 1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = v.Holder
                    }
                end
            end
        end
        Races[RaceId].LastLeaderboard = LastRaces[RaceId]
        Races[RaceId].Racers = {}
        Races[RaceId].Started = false
        Races[RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        exports.qbx_core:Notify(src, locale('error.raceended'), 'error')
        TriggerClientEvent('qb-lapraces:client:LeaveRace', src, Races[RaceId])
        LastRaces[RaceId] = nil
        NotFinished[RaceId] = nil
    else
        AvailableRaces[AvailableKey].RaceData = Races[RaceId]
        TriggerClientEvent('qb-lapraces:client:LeaveRace', src, Races[RaceId])
    end
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('qb-lapraces:server:SetupRace', function(RaceId, Laps)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player or type(RaceId) ~= 'string' or not isInteger(Laps)
        or Laps < 0 or Laps > MAX_RACE_LAPS or not Config.RaceSetupAllowed
        or HasOpenedRace(Player.PlayerData.citizenid) then return end

    if Races[RaceId] then
        if not Races[RaceId].Waiting then
            if not Races[RaceId].Started then
                Races[RaceId].Waiting = true
                AvailableRaces[#AvailableRaces + 1] = {
                    RaceData = Races[RaceId],
                    Laps = Laps,
                    RaceId = RaceId,
                    SetupCitizenId = Player.PlayerData.citizenid
                }
                TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
                SetTimeout(5 * 60 * 1000, function()
                    if Races[RaceId].Waiting then
                        local AvailableKey = GetOpenedRaceKey(RaceId)
                        for cid in pairs(Races[RaceId].Racers) do
                            local RacerData = exports.qbx_core:GetPlayerByCitizenId(cid)
                            if RacerData then
                                TriggerClientEvent('qb-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
                            end
                        end
                        table.remove(AvailableRaces, AvailableKey)
                        Races[RaceId].LastLeaderboard = {}
                        Races[RaceId].Racers = {}
                        Races[RaceId].Started = false
                        Races[RaceId].Waiting = false
                        LastRaces[RaceId] = nil
                        TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
                    end
                end)
            else
                exports.qbx_core:Notify(source, locale('error.alreadyrunning'), 'error')
            end
        else
            exports.qbx_core:Notify(source, locale('error.alreadyrunning'), 'error')
        end
    else
        exports.qbx_core:Notify(source, locale('error.notexist'), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:CancelRace', function(raceId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player or type(raceId) ~= 'string' or not Races[raceId] then return end

    local AvailableKey = GetOpenedRaceKey(raceId)

    exports.qbx_core:Notify(src, locale('error.stoppingrace',raceId), 'error')

    if AvailableKey then
        if AvailableRaces[AvailableKey].SetupCitizenId == Player.PlayerData.citizenid then
            for cid in pairs(Races[raceId].Racers) do
                local RacerData = exports.qbx_core:GetPlayerByCitizenId(cid)
                if RacerData then
                    TriggerClientEvent('qb-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[raceId])
                end
            end

            table.remove(AvailableRaces, AvailableKey)
            Races[raceId].LastLeaderboard = {}
            Races[raceId].Racers = {}
            Races[raceId].Started = false
            Races[raceId].Waiting = false
            LastRaces[raceId] = nil
            TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
        end
    else
        exports.qbx_core:Notify(src, locale('error.racenotopen', raceId), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:UpdateRacerData', function(RaceId, Checkpoint, Lap, Finished)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player or type(RaceId) ~= 'string' or not isInteger(Checkpoint)
        or not isInteger(Lap) or type(Finished) ~= 'boolean' then return end

    local CitizenId = Player.PlayerData.citizenid
    if GetCurrentRace(CitizenId) ~= RaceId then return end

    local race = Races[RaceId]
    local AvailableKey = GetOpenedRaceKey(RaceId)
    local availableRace = AvailableKey and AvailableRaces[AvailableKey]
    local racer = race and race.Racers[CitizenId]
    if not race or not availableRace or not race.Started or not racer or racer.Finished then return end

    local checkpointCount = #race.Checkpoints
    local totalLaps = availableRace.Laps
    local validTransition
    if Finished then
        if totalLaps == 0 then
            validTransition = Checkpoint == checkpointCount
                and racer.Checkpoint == checkpointCount - 1 and Lap == racer.Lap
        else
            validTransition = Checkpoint == checkpointCount + 1
                and racer.Checkpoint == checkpointCount and Lap == totalLaps
        end
    else
        validTransition = Checkpoint == racer.Checkpoint + 1
            and Checkpoint <= checkpointCount and Lap == racer.Lap
        if not validTransition and totalLaps > 0 then
            validTransition = racer.Checkpoint == checkpointCount and Checkpoint == 1
                and Lap == racer.Lap + 1 and Lap <= totalLaps
        end
    end
    if not validTransition then return end

    local now = GetGameTimer()
    if not racer.StartedAt or now < racer.StartedAt then return end

    local targetIndex = Checkpoint > checkpointCount and 1 or Checkpoint
    local target = race.Checkpoints[targetIndex]
    local targetCoords = target and validateCoords(target.coords)
    local playerPed = GetPlayerPed(src)
    if not targetCoords or playerPed <= 0 or #(GetEntityCoords(playerPed) - targetCoords) > 25 then return end

    if Finished then
        local lapMultiplier = totalLaps > 0 and totalLaps or 1
        local raceDistance = tonumber(race.Distance)
        if not isFiniteNumber(raceDistance) or raceDistance <= 0 then return end
        local minimumTime = math.max(1, raceDistance * lapMultiplier / MAX_PLAUSIBLE_SPEED)
        if (now - racer.StartedAt) / 1000 < minimumTime then return end
    end

    if (Checkpoint == 1 and Lap > racer.Lap) or Finished then
        local lapTime = math.max(1, math.floor((now - racer.LapStartedAt) / 1000))
        racer.BestLap = not racer.BestLap and lapTime or math.min(racer.BestLap, lapTime)
        racer.LapStartedAt = now
    end

    racer.Checkpoint = Checkpoint
    racer.Lap = Lap
    racer.Finished = Finished
    if Finished then racer.FinishedAt = now end

    TriggerClientEvent('qb-lapraces:client:UpdateRaceRacerData', -1, RaceId, race)
end)

RegisterNetEvent('qb-lapraces:server:StartRace', function(RaceId)
    local src = source
    local MyPlayer = exports.qbx_core:GetPlayer(src)
    if not MyPlayer or type(RaceId) ~= 'string' then return end

    local AvailableKey = GetOpenedRaceKey(RaceId)
    local availableRace = AvailableKey and AvailableRaces[AvailableKey]
    local race = Races[RaceId]

    if race and availableRace then
        if availableRace.SetupCitizenId == MyPlayer.PlayerData.citizenid then
            if race.Started or not race.Waiting then return end

            race.Started = true
            race.Waiting = false
            local startsAt = GetGameTimer() + 10000
            local startCoords = validateCoords(race.Checkpoints[1] and race.Checkpoints[1].coords)
            local validRacers = 0
            for CitizenId, racer in pairs(race.Racers) do
                local Player = exports.qbx_core:GetPlayerByCitizenId(CitizenId)
                local playerPed = Player and GetPlayerPed(Player.PlayerData.source)
                if Player and startCoords and playerPed > 0
                    and #(GetEntityCoords(playerPed) - startCoords) <= 125 then
                    validRacers += 1
                    racer.Checkpoint = 1
                    racer.Lap = 1
                    racer.Finished = false
                    racer.StartedAt = startsAt
                    racer.LapStartedAt = startsAt
                    racer.BestLap = nil
                    racer.FinishedAt = nil
                    racer.ResultRecorded = nil
                    TriggerClientEvent('qb-lapraces:client:RaceCountdown', Player.PlayerData.source)
                else
                    if Player then
                        TriggerClientEvent('qb-lapraces:client:LeaveRace', Player.PlayerData.source, race)
                    end
                    race.Racers[CitizenId] = nil
                end
            end
            if validRacers == 0 then
                race.Started = false
                race.Waiting = true
                return
            end
            TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
        else
            exports.qbx_core:Notify(src, locale('error.notcreator'), 'error')
        end
    else
        exports.qbx_core:Notify(src, locale('error.notinarace'), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:SaveRace', function(RaceData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local RaceName = RaceEditors[src]
    if not Player or not RaceName or not IsWhitelisted(Player.PlayerData.citizenid)
        or type(RaceData) ~= 'table' or RaceData.RaceName ~= RaceName
        or not IsNameAvailable(RaceName) then return end

    local Checkpoints, RaceDistance = validateCheckpoints(RaceData.Checkpoints)
    if not Checkpoints then return end

    local RaceId = GenerateRaceId()
    Races[RaceId] = {
        RaceName = RaceName,
        Checkpoints = Checkpoints,
        Records = {},
        Creator = Player.PlayerData.citizenid,
        RaceId = RaceId,
        Started = false,
        Waiting = false,
        Distance = math.ceil(RaceDistance),
        Racers = {},
        LastLeaderboard = {}
    }
    RaceEditors[src] = nil
    MySQL.insert(
        'INSERT INTO lapraces (name, checkpoints, creator, distance, raceid) VALUES (?, ?, ?, ?, ?)',
        {RaceName, json.encode(Checkpoints), Player.PlayerData.citizenid, math.ceil(RaceDistance), RaceId}
    )
end)

-- Callbacks

lib.callback.register('qb-lapraces:server:GetRacingLeaderboards', function()
    return Races
end)

lib.callback.register('qb-lapraces:server:GetRaces', function()
    return AvailableRaces
end)

lib.callback.register('qb-lapraces:server:GetListedRaces', function()
    return Races
end)

lib.callback.register('qb-lapraces:server:GetRacingData', function(_, RaceId)
    return Races[RaceId]
end)

lib.callback.register('qb-lapraces:server:HasCreatedRace', function(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and HasOpenedRace(player.PlayerData.citizenid) or false
end)

lib.callback.register('qb-lapraces:server:IsAuthorizedToCreateRaces', function(source, TrackName)
    local player = exports.qbx_core:GetPlayer(source)
    if not player or type(TrackName) ~= 'string' then return false, false end
    return IsWhitelisted(player.PlayerData.citizenid), IsNameAvailable(TrackName)
end)

lib.callback.register('qb-lapraces:server:CanRaceSetup', function(_, cb)
    return Config.RaceSetupAllowed
end)

lib.callback.register('qb-lapraces:server:GetTrackData', function(_, RaceId)
    local race = type(RaceId) == 'string' and Races[RaceId]
    if not race then return end

    local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {race.Creator})
    if result and result[1] then
        result[1].charinfo = json.decode(result[1].charinfo)
        return race, result[1]
    end

    return race, {
        charinfo = {
            firstname = locale('general.unknown'),
            lastname = locale('general.unknown')
        }
    }
end)

-- Commands

lib.addCommand('cancelrace', {help = locale('commands.cancelrace')}, function(source, args)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return end

    if IsWhitelisted(Player.PlayerData.citizenid) then
        local RaceName = table.concat(args, " ")
        if RaceName and RaceName ~= '' then
            local RaceId = GetRaceId(RaceName)
            if RaceId and Races[RaceId].Started then
                local AvailableKey = GetOpenedRaceKey(RaceId)
                for cid in pairs(Races[RaceId].Racers) do
                    local RacerData = exports.qbx_core:GetPlayerByCitizenId(cid)
                    if RacerData then
                        TriggerClientEvent('qb-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
                    end
                end
                table.remove(AvailableRaces, AvailableKey)
                Races[RaceId].LastLeaderboard = {}
                Races[RaceId].Racers = {}
                Races[RaceId].Started = false
                Races[RaceId].Waiting = false
                LastRaces[RaceId] = nil
                TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
            else
                exports.qbx_core:Notify(source, locale('error.notstarted'), 'error')
            end
        end
    else
        exports.qbx_core:Notify(source, locale('error.notauthorized', locale('general.dothis')), 'error')
    end
end)

lib.addCommand('togglesetup', {help = locale('commands.togglesetup')}, function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return end
    if IsWhitelisted(Player.PlayerData.citizenid) then
        Config.RaceSetupAllowed = not Config.RaceSetupAllowed
        if not Config.RaceSetupAllowed then
            exports.qbx_core:Notify(source, locale('error.nomoreraces'), 'error')
        else
            exports.qbx_core:Notify(source, locale('success.cancreate'), 'success')
        end
    else
        exports.qbx_core:Notify(source, locale('error.notauthorized', locale('general.dothis')), 'error')
    end
end)

AddEventHandler('playerDropped', function()
    RaceEditors[source] = nil
end)

-- Threads

CreateThread(function()
    local races = MySQL.query.await('SELECT * FROM lapraces', {})
    if races and races[1] then
        for _, v in pairs(races) do
            local Records = v.records and json.decode(v.records) or {}
            Races[v.raceid] = {
                RaceName = v.name,
                Checkpoints = json.decode(v.checkpoints),
                Records = Records,
                Creator = v.creator,
                RaceId = v.raceid,
                Started = false,
                Waiting = false,
                Distance = v.distance,
                LastLeaderboard = {},
                Racers = {}
            }
        end
    end
end)
