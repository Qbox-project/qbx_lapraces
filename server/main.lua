local Races = {}
local AvailableRaces = {}
local LastRaces = {}
local NotFinished = {}

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

RegisterNetEvent('qb-lapraces:server:FinishPlayer', function(RaceData, TotalTime, TotalLaps, BestLap)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local PlayersFinished = 0
    local AmountOfRacers = 0

    for _, v in pairs(Races[RaceData.RaceId].Racers) do
        if v.Finished then
            PlayersFinished += 1
        end
        AmountOfRacers += 1
    end

    BestLap = TotalLaps < 2 and TotalTime or BestLap
    if LastRaces[RaceData.RaceId] then
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId] + 1] =  {
            TotalTime = TotalTime,
            BestLap = BestLap,
            Holder = {
                Player.PlayerData.charinfo.firstname,
                Player.PlayerData.charinfo.lastname
            }
        }
    else
        LastRaces[RaceData.RaceId] = {}
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId] + 1] =  {
            TotalTime = TotalTime,
            BestLap = BestLap,
            Holder = {
                Player.PlayerData.charinfo.firstname,
                Player.PlayerData.charinfo.lastname
            }
        }
    end
    if Races[RaceData.RaceId].Records and table.type(Races[RaceData.RaceId].Records) ~= 'empty' then
        if BestLap < Races[RaceData.RaceId].Records.Time then
            Races[RaceData.RaceId].Records = {
                Time = BestLap,
                Holder = {
                    Player.PlayerData.charinfo.firstname,
                    Player.PlayerData.charinfo.lastname
                }
            }
            MySQL.update('UPDATE lapraces SET records = ? WHERE raceid = ?', {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
            TriggerClientEvent('qb-phone:client:RaceNotify', src, Lang:t('phonenotif.wonWR', {Racename = RaceData.RaceName, timeof = SecondsToClock(BestLap)}))
        end
    else
        Races[RaceData.RaceId].Records = {
            Time = BestLap,
            Holder = {
                Player.PlayerData.charinfo.firstname,
                Player.PlayerData.charinfo.lastname
            }
        }
        MySQL.update('UPDATE lapraces SET records = ? WHERE raceid = ?', {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
        TriggerClientEvent('qb-phone:client:RaceNotify', src, Lang:t('phonenotif.wonWR2', {Racename = RaceData.RaceName, timeof = SecondsToClock(BestLap)}))
    end
    AvailableRaces[AvailableKey].RaceData = Races[RaceData.RaceId]
    TriggerClientEvent('qb-lapraces:client:PlayerFinishs', -1, RaceData.RaceId, PlayersFinished, Player)
    if PlayersFinished == AmountOfRacers then
        if NotFinished and table.type(NotFinished) ~= 'empty' and NotFinished[RaceData.RaceId] and table.type(NotFinished[RaceData.RaceId]) ~= 'empty' then
            for _, v in pairs(NotFinished[RaceData.RaceId]) do
                LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId] + 1] = {
                    TotalTime = v.TotalTime,
                    BestLap = v.BestLap,
                    Holder = v.Holder
                }
            end
        end
        Races[RaceData.RaceId].LastLeaderboard = LastRaces[RaceData.RaceId]
        Races[RaceData.RaceId].Racers = {}
        Races[RaceData.RaceId].Started = false
        Races[RaceData.RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        LastRaces[RaceData.RaceId] = nil
        NotFinished[RaceData.RaceId] = nil
    end
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('qb-lapraces:server:CreateLapRace', function(RaceName)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if Player and IsWhitelisted(Player.PlayerData.citizenid) then
        if IsNameAvailable(RaceName) then
            TriggerClientEvent('qb-lapraces:client:StartRaceEditor', source, RaceName)
        else
            exports.qbx_core:Notify(source, Lang:t('error.namealreadyused'), 'error')
        end
    else
        exports.qbx_core:Notify(source, Lang:t('error.notauthorized', {to = Lang:t('general.createraces')}), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:JoinRace', function(RaceData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local RaceId = RaceData.RaceId
    local AvailableKey = GetOpenedRaceKey(RaceId)
    local CurrentRace = GetCurrentRace(Player.PlayerData.citizenid)
    if CurrentRace then
        local AmountOfRacers = 0
        local PreviousRaceKey = GetOpenedRaceKey(CurrentRace)
        for _ in pairs(Races[CurrentRace].Racers) do
            AmountOfRacers += 1
        end
        Races[CurrentRace].Racers[Player.PlayerData.citizenid] = nil
        if AmountOfRacers - 1 == 0 then
            Races[CurrentRace].Racers = {}
            Races[CurrentRace].Started = false
            Races[CurrentRace].Waiting = false
            table.remove(AvailableRaces, PreviousRaceKey)
            exports.qbx_core:Notify(src, Lang:t('error.raceended'), 'error')
            TriggerClientEvent('qb-lapraces:client:LeaveRace', src, Races[CurrentRace])
        else
            AvailableRaces[PreviousRaceKey].RaceData = Races[CurrentRace]
            TriggerClientEvent('qb-lapraces:client:LeaveRace', src, Races[CurrentRace])
        end
        TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
    end
    Races[RaceId].Waiting = true
    Races[RaceId].Racers[Player.PlayerData.citizenid] = {
        Checkpoint = 0,
        Lap = 1,
        Finished = false
    }
    AvailableRaces[AvailableKey].RaceData = Races[RaceId]
    TriggerClientEvent('qb-lapraces:client:JoinRace', src, Races[RaceId], AvailableRaces[AvailableKey].Laps)
    TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
    local creatorsource = exports.qbx_core:GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId).PlayerData.source
    if creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('qb-phone:client:RaceNotify', creatorsource, Lang:t('phonenotif.joinedrace', {firstname = string.sub(Player.PlayerData.charinfo.firstname, 1, 1), lastname = Player.PlayerData.charinfo.lastname}))
    end
end)

RegisterNetEvent('qb-lapraces:server:LeaveRace', function(RaceData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local RaceName = RaceData.RaceData and RaceData.RaceData.RaceName or RaceData.RaceName
    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local creatorsource = exports.qbx_core:GetPlayerByCitizenId(AvailableRaces[AvailableKey].SetupCitizenId)?.PlayerData.source
    if creatorsource ~= Player.PlayerData.source then
        TriggerClientEvent('qb-phone:client:RaceNotify', creatorsource, Lang:t('phonenotif.LeaveRace', {firstname = string.sub(Player.PlayerData.charinfo.firstname, 1, 1), lastname = Player.PlayerData.charinfo.lastname}))
    end
    local AmountOfRacers = 0
    for _ in pairs(Races[RaceData.RaceId].Racers) do
        AmountOfRacers += 1
    end
    if NotFinished[RaceData.RaceId] then
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId] + 1] = {
            TotalTime = Lang:t('general.DNF'),
            BestLap = Lang:t('general.DNF'),
            Holder = {
                Player.PlayerData.charinfo.firstname,
                Player.PlayerData.charinfo.lastname
            }
        }
    else
        NotFinished[RaceData.RaceId] = {}
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId] + 1] = {
            TotalTime = Lang:t('general.DNF'),
            BestLap = Lang:t('general.DNF'),
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
        exports.qbx_core:Notify(src, Lang:t('error.raceended'), 'error')
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
                exports.qbx_core:Notify(source, Lang:t('error.alreadyrunning'), 'error')
            end
        else
            exports.qbx_core:Notify(source, Lang:t('error.alreadyrunning'), 'error')
        end
    else
        exports.qbx_core:Notify(source, Lang:t('error.notexist'), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:CancelRace', function(raceId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(source)
    local AvailableKey = GetOpenedRaceKey(raceId)

    exports.qbx_core:Notify(src, Lang:t('error.stoppingrace', {RaceId = raceId}), 'error')

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
        exports.qbx_core:Notify(src, Lang:t('error.racenotopen', {RaceId = raceId}), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:UpdateRaceState', function(RaceId, Started, Waiting)
    Races[RaceId].Waiting = Waiting
    Races[RaceId].Started = Started
end)

RegisterNetEvent('qb-lapraces:server:UpdateRacerData', function(RaceId, Checkpoint, Lap, Finished)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local CitizenId = Player.PlayerData.citizenid

    Races[RaceId].Racers[CitizenId].Checkpoint = Checkpoint
    Races[RaceId].Racers[CitizenId].Lap = Lap
    Races[RaceId].Racers[CitizenId].Finished = Finished

    TriggerClientEvent('qb-lapraces:client:UpdateRaceRacerData', -1, RaceId, Races[RaceId])
end)

RegisterNetEvent('qb-lapraces:server:StartRace', function(RaceId)
    local src = source
    local MyPlayer = exports.qbx_core:GetPlayer(src)
    local AvailableKey = GetOpenedRaceKey(RaceId)

    if RaceId then
        if AvailableRaces[AvailableKey].SetupCitizenId == MyPlayer.PlayerData.citizenid then
            AvailableRaces[AvailableKey].RaceData.Started = true
            AvailableRaces[AvailableKey].RaceData.Waiting = false
            for CitizenId in pairs(Races[RaceId].Racers) do
                local Player = exports.qbx_core:GetPlayerByCitizenId(CitizenId)
                if Player then
                    TriggerClientEvent('qb-lapraces:client:RaceCountdown', Player.PlayerData.source)
                end
            end
            TriggerClientEvent('qb-phone:client:UpdateLapraces', -1)
        else
            exports.qbx_core:Notify(src, Lang:t('error.notcreator'), 'error')
        end
    else
        exports.qbx_core:Notify(src, Lang:t('error.notinarace'), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:server:SaveRace', function(RaceData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    local RaceId = GenerateRaceId()
    local Checkpoints = {}
    for k, v in pairs(RaceData.Checkpoints) do
        Checkpoints[k] = {
            offset = v.offset,
            coords = v.coords
        }
    end
    Races[RaceId] = {
        RaceName = RaceData.RaceName,
        Checkpoints = Checkpoints,
        Records = {},
        Creator = Player.PlayerData.citizenid,
        RaceId = RaceId,
        Started = false,
        Waiting = false,
        Distance = math.ceil(RaceData.RaceDistance),
        Racers = {},
        LastLeaderboard = {}
    }
    MySQL.insert('INSERT INTO lapraces (name, checkpoints, creator, distance, raceid) VALUES (?, ?, ?, ?, ?)', {RaceData.RaceName, json.encode(Checkpoints), Player.PlayerData.citizenid, RaceData.RaceDistance, GenerateRaceId()})
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
    return HasOpenedRace(exports.qbx_core:GetPlayer(source).PlayerData.citizenid)
end)

lib.callback.register('qb-lapraces:server:IsAuthorizedToCreateRaces', function(source, TrackName)
    return IsWhitelisted(exports.qbx_core:GetPlayer(source).PlayerData.citizenid), IsNameAvailable(TrackName)
end)

lib.callback.register('qb-lapraces:server:CanRaceSetup', function(_, cb)
    return Config.RaceSetupAllowed
end)

lib.callback.register('qb-lapraces:server:GetTrackData', function(_, RaceId)
    local result = MySQL.query.await('SELECT * FROM players WHERE citizenid = ?', {Races[RaceId].Creator})
    if result and result[1] then
        result[1].charinfo = json.decode(result[1].charinfo)
        return Races[RaceId], result[1]
    end

    return Races[RaceId], {
        charinfo = {
            firstname = Lang:t('general.unknown'),
            lastname = Lang:t('general.unknown')
        }
    }
end)

-- Commands

lib.addCommand('cancelrace', {help = Lang:t('commands.cancelrace')}, function(source, args)
    local Player = exports.qbx_core:GetPlayer(source)

    if IsWhitelisted(Player.PlayerData.citizenid) then
        local RaceName = table.concat(args, " ")
        if RaceName then
            local RaceId = GetRaceId(RaceName)
            if Races[RaceId].Started then
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
                exports.qbx_core:Notify(source, Lang:t('error.notstarted'), 'error')
            end
        end
    else
        exports.qbx_core:Notify(source, Lang:t('error.notauthorized', {to = Lang:t('general.dothis')}), 'error')
    end
end)

lib.addCommand('togglesetup', {help = Lang:t('commands.togglesetup')}, function(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if IsWhitelisted(Player.PlayerData.citizenid) then
        Config.RaceSetupAllowed = not Config.RaceSetupAllowed
        if not Config.RaceSetupAllowed then
            exports.qbx_core:Notify(source, Lang:t('error.nomoreraces'), 'error')
        else
            exports.qbx_core:Notify(source, Lang:t('success.cancreate'), 'success')
        end
    else
        exports.qbx_core:Notify(source, Lang:t('error.notauthorized', {to = Lang:t('general.dothis')}), 'error')
    end
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
