local Countdown = 10
local ToFarCountdown = 10
local FinishedUITimeout = false

local RaceData = {
    InCreator = false,
    InRace = false,
    ClosestCheckpoint = 0,
}

local CreatorData = {
    RaceName = nil,
    Checkpoints = {},
    TireDistance = 3.0,
    ConfirmDelete = false,
}

local CurrentRaceData = {
    RaceId = nil,
    RaceName = nil,
    Checkpoints = {},
    Started = false,
    CurrentCheckpoint = nil,
    TotalLaps = 0,
    Lap = 0,
}

-- Handlers

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, v in pairs(CreatorData.Checkpoints) do
        if v.pileleft then
            local coords = v.offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileright = nil
        end
        if v.pileright then
            local coords = v.offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileright = nil
        end
    end

    for _, v in pairs(CurrentRaceData.Checkpoints) do
        if v.pileleft then
            local coords = v.offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileright = nil
        end
        if v.pileright then
            local coords = v.offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileright = nil
        end
    end
end)

-- Functions

local function GetClosestCheckpoint()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local dist = nil
    for id, v in pairs(CreatorData.Checkpoints) do
        local dist2 = #(pos - v.coords.xyz)
        if current then
            if dist2 < dist then
                current = id
                dist = dist2
            end
        else
            dist = dist2
            current = id
        end
    end
    RaceData.ClosestCheckpoint = current
end

local function SetupPiles()
    for _, v in pairs(CreatorData.Checkpoints) do
        if not v.pileleft then
            ClearAreaOfObjects(v.offset.left.x, v.offset.left.y, v.offset.left.z, 50.0, 0)
            v.pileleft = CreateObject(`prop_offroad_tyres02`, v.offset.left.x, v.offset.left.y, v.offset.left.z, false, false, false)
            PlaceObjectOnGroundProperly(v.pileleft)
            FreezeEntityPosition(v.pileleft, true)
            SetEntityAsMissionEntity(v.pileleft, true, true)
        end

        if not v.pileright then
            ClearAreaOfObjects(v.offset.right.x, v.offset.right.y, v.offset.right.z, 50.0, 0)
            v.pileright = CreateObject(`prop_offroad_tyres02`, v.offset.right.x, v.offset.right.y, v.offset.right.z, false, false, false)
            PlaceObjectOnGroundProperly(v.pileright)
            FreezeEntityPosition(v.pileleft, true)
            SetEntityAsMissionEntity(v.pileleft, true, true)
        end
    end
end

local function CheckpointLoop()
    CreateThread(function()
        while RaceData.InCreator do
            GetClosestCheckpoint()
            SetupPiles()
            Wait(1000)
        end
    end)
end

local function PylonsLoop()
    CreateThread(function()
        while RaceData.InCreator do
            if cache.vehicle then
                local left = GetOffsetFromEntityInWorldCoords(cache.vehicle, -CreatorData.TireDistance, 0.0, 0.0)
                local right = GetOffsetFromEntityInWorldCoords(cache.vehicle, -CreatorData.TireDistance, 0.0, 0.0)
                qbx.drawText3d({text = Lang:t('general.CheckL'), coords = vec3(left.x, left.y, left.z)})
                qbx.drawText3d({text = Lang:t('general.CheckR'), coords = vec3(right.x, right.y, right.z)})
            end
            Wait(0)
        end
    end)
end

local function CreatorUI()
    CreateThread(function()
        while true do
            if RaceData.InCreator then
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = true,
                })
            else
                SendNUIMessage({
                    action = "Update",
                    type = "creator",
                    data = CreatorData,
                    racedata = RaceData,
                    active = false,
                })
                break
            end
            Wait(200)
        end
    end)
end

local function DeleteCheckpoint()
    local NewCheckpoints = {}
    if RaceData.ClosestCheckpoint ~= 0 then
        local curCheckpoint = CreatorData.Checkpoints[RaceData.ClosestCheckpoint]
        if curCheckpoint then
            if curCheckpoint.blip then
                RemoveBlip(curCheckpoint.blip)
                curCheckpoint.blip = nil
            end
            if curCheckpoint.pileleft then
                local coords = curCheckpoint.offset.left
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                curCheckpoint.pileleft = nil
            end
            if curCheckpoint.pileright then
                local coords = curCheckpoint.offset.right
                local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
                DeleteObject(Obj)
                ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                curCheckpoint.pileright = nil
            end

            for id, data in pairs(CreatorData.Checkpoints) do
                if id ~= RaceData.ClosestCheckpoint then
                    NewCheckpoints[#NewCheckpoints + 1] = data
                end
            end
            CreatorData.Checkpoints = NewCheckpoints
        else
            exports.qbx_core:Notify(Lang:t('error.toofast'), 'error')
        end
    else
        exports.qbx_core:Notify(Lang:t('error.toofast'), 'error')
    end
end

local function SaveRace()
    local RaceDistance = 0

    for k, v in pairs(CreatorData.Checkpoints) do
        if k + 1 <= #CreatorData.Checkpoints then
            local checkpointdistance = #(v.coords - CreatorData.Checkpoints[k + 1].coords)
            RaceDistance += checkpointdistance
        end
    end

    CreatorData.RaceDistance = RaceDistance

    TriggerServerEvent('qb-lapraces:server:SaveRace', CreatorData)

    exports.qbx_core:Notify(Lang:t('success.savedrace', {racename = CreatorData.RaceName}), 'success')

    for _, v in pairs(CreatorData.Checkpoints) do
        if v.blip then
            RemoveBlip(v.blip)
            v.blip = nil
        end

        if v.pileleft then
            local coords = v.offset.left
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileleft = nil
        end
        if v.pileright then
            local coords = v.offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileright = nil
        end
    end

    RaceData.InCreator = false
    CreatorData.RaceName = nil
    CreatorData.Checkpoints = {}
end

local function AddCheckpoint()
    local offset = {
        left = GetOffsetFromEntityInWorldCoords(cache.vehicle, -CreatorData.TireDistance, 0.0, 0.0),
        right = GetOffsetFromEntityInWorldCoords(cache.vehicle, CreatorData.TireDistance, 0.0, 0.0)
    }

    CreatorData.Checkpoints[#CreatorData.Checkpoints + 1] = {
        coords = GetEntityCoords(cache.ped),
        offset = offset,
    }

    for id, checkpointData in pairs(CreatorData.Checkpoints) do
        if checkpointData.blip then
            RemoveBlip(checkpointData.blip)
        end

        checkpointData.blip = AddBlipForCoord(checkpointData.coords.x, checkpointData.coords.y, checkpointData.coords.z)

        SetBlipSprite(checkpointData.blip, 1)
        SetBlipDisplay(checkpointData.blip, 4)
        SetBlipScale(checkpointData.blip, 0.8)
        SetBlipAsShortRange(checkpointData.blip, true)
        SetBlipColour(checkpointData.blip, 26)
        ShowNumberOnBlip(checkpointData.blip, id)
        SetBlipShowCone(checkpointData.blip, false)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Checkpoint: "..id)
        EndTextCommandSetBlipName(checkpointData.blip)
    end
end

local function CreatorLoop()
    CreateThread(function()
        while RaceData.InCreator do
            if cache.vehicle then
                if IsControlJustPressed(0, 161) or IsDisabledControlJustPressed(0, 161) then
                    AddCheckpoint()
                end

                if IsControlJustPressed(0, 162) or IsDisabledControlJustPressed(0, 162) then
                    if CreatorData.Checkpoints and table.type(CreatorData.Checkpoints) ~= 'empty' then
                        DeleteCheckpoint()
                    else
                        exports.qbx_core:Notify(Lang:t('error.nocheckpoints'), 'error')
                    end
                end

                if IsControlJustPressed(0, 311) or IsDisabledControlJustPressed(0, 311) then
                    if CreatorData.Checkpoints and #CreatorData.Checkpoints >= 2 then
                        SaveRace()
                    else
                        exports.qbx_core:Notify(Lang:t('error.atleast10checkp'), 'error')
                    end
                end

                if IsControlJustPressed(0, 40) or IsDisabledControlJustPressed(0, 40) then
                    if CreatorData.TireDistance + 1.0 ~= 16.0 then
                        CreatorData.TireDistance = CreatorData.TireDistance + 1.0
                    else
                        exports.qbx_core:Notify(Lang:t('error.higherthan15'), 'error')
                    end
                end

                if IsControlJustPressed(0, 39) or IsDisabledControlJustPressed(0, 39) then
                    if CreatorData.TireDistance - 1.0 ~= 1.0 then
                        CreatorData.TireDistance = CreatorData.TireDistance - 1.0
                    else
                        exports.qbx_core:Notify(Lang:t('error.lowerthan2'), 'error')
                    end
                end
            else
                local coords = GetEntityCoords(cache.ped)
                qbx.drawText3d({text = Lang:t('error.mustbeinveh'), coords = vec3(coords.x, coords.y, coords.z)})
            end

            if IsControlJustPressed(0, 163) or IsDisabledControlJustPressed(0, 163) then
                if not CreatorData.ConfirmDelete then
                    CreatorData.ConfirmDelete = true
                    exports.qbx_core:Notify(Lang:t('error.pressagain'), 'error', 5000)
                else
                    for _, checkpointData in pairs(CreatorData.Checkpoints) do
                        if checkpointData.blip then
                            RemoveBlip(checkpointData.blip)
                        end
                    end

                    for _, v in pairs(CreatorData.Checkpoints) do
                        if v.pileleft then
                            local coords = v.offset.left
                            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 8.0, `prop_offroad_tyres02`, false, false, false)
                            DeleteObject(Obj)
                            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                            v.pileleft = nil
                        end

                        if v.pileright then
                            local coords = v.offset.right
                            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 8.0, `prop_offroad_tyres02`, false, false, false)
                            DeleteObject(Obj)
                            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
                            v.pileright = nil
                        end
                    end

                    RaceData.InCreator = false
                    CreatorData.RaceName = nil
                    CreatorData.Checkpoints = {}
                    exports.qbx_core:Notify(Lang:t('error.editorcancelled'), 'error')
                    CreatorData.ConfirmDelete = false
                end
            end
            Wait(0)
        end
    end)
end

local function RaceUI()
    CreateThread(function()
        while true do
            if CurrentRaceData.Checkpoints and table.type(CurrentRaceData.Checkpoints) ~= 'empty' then
                if CurrentRaceData.Started then
                    CurrentRaceData.RaceTime += 1
                    CurrentRaceData.TotalTime += 1
                end
                SendNUIMessage({
                    action = "Update",
                    type = "race",
                    data = {
                        CurrentCheckpoint = CurrentRaceData.CurrentCheckpoint,
                        TotalCheckpoints = #CurrentRaceData.Checkpoints,
                        TotalLaps = CurrentRaceData.TotalLaps,
                        CurrentLap = CurrentRaceData.Lap,
                        RaceStarted = CurrentRaceData.Started,
                        RaceName = CurrentRaceData.RaceName,
                        Time = CurrentRaceData.RaceTime,
                        TotalTime = CurrentRaceData.TotalTime,
                        BestLap = CurrentRaceData.BestLap,
                    },
                    racedata = RaceData,
                    active = true,
                })
            else
                if not FinishedUITimeout then
                    FinishedUITimeout = true
                    SetTimeout(10000, function()
                        FinishedUITimeout = false
                        SendNUIMessage({
                            action = "Update",
                            type = "race",
                            data = {},
                            racedata = RaceData,
                            active = false,
                        })
                    end)
                end
                break
            end
            Wait(0)
        end
    end)
end

local function SetupRace(sRaceData, Laps)
    RaceData.RaceId = sRaceData.RaceId
    CurrentRaceData = {
        RaceId = sRaceData.RaceId,
        Creator = sRaceData.Creator,
        RaceName = sRaceData.RaceName,
        Checkpoints = sRaceData.Checkpoints,
        Started = false,
        CurrentCheckpoint = 1,
        TotalLaps = Laps,
        Lap = 1,
        RaceTime = 0,
        TotalTime = 0,
        BestLap = 0,
        Racers = {}
    }

    for k, v in pairs(CurrentRaceData.Checkpoints) do
        ClearAreaOfObjects(v.offset.left.x, v.offset.left.y, v.offset.left.z, 50.0, 0)
        v.pileleft = CreateObject(`prop_offroad_tyres02`, v.offset.left.x, v.offset.left.y, v.offset.left.z, false, false, false)
        PlaceObjectOnGroundProperly(v.pileleft)
        FreezeEntityPosition(v.pileleft, true)
        SetEntityAsMissionEntity(v.pileleft, true, true)

        ClearAreaOfObjects(v.offset.right.x, v.offset.right.y, v.offset.right.z, 50.0, 0)
        v.pileright = CreateObject(`prop_offroad_tyres02`, v.offset.right.x, v.offset.right.y, v.offset.right.z, false, false, false)
        PlaceObjectOnGroundProperly(v.pileright)
        FreezeEntityPosition(v.pileright, true)
        SetEntityAsMissionEntity(v.pileright, true, true)

        v.blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
        SetBlipSprite(v.blip, 1)
        SetBlipDisplay(v.blip, 4)
        SetBlipScale(v.blip, 0.6)
        SetBlipAsShortRange(v.blip, true)
        SetBlipColour(v.blip, 26)
        ShowNumberOnBlip(v.blip, k)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Checkpoint: "..k)
        EndTextCommandSetBlipName(v.blip)
    end

    RaceUI()
end

local function showNonLoopParticle(dict, particleName, coords, scale)
    lib.requestNamedPtfxAsset(dict)
    UseParticleFxAssetNextCall(dict)
    local particleHandle = StartParticleFxLoopedAtCoord(particleName, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, scale, false, false, false, false)
    SetParticleFxLoopedColour(particleHandle, 0, 255, 0, false)
    return particleHandle
end

local function DoPilePfx()
    if not CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint] then return end

    local Timeout = 500
    local Size = 2.0
    local left = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.left, Size)
    local right = showNonLoopParticle('core', 'ent_sht_flame', CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].offset.right, Size)

    SetTimeout(Timeout, function()
        StopParticleFxLooped(left, false)
        StopParticleFxLooped(right, false)
    end)
end

local function GetMaxDistance(offsetCoords)
    return #(offsetCoords.left - offsetCoords.right) > 20.0 and 12.5 or 7.5
end

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

local function FinishRace()
    TriggerServerEvent('qb-lapraces:server:FinishPlayer', CurrentRaceData, CurrentRaceData.TotalTime, CurrentRaceData.TotalLaps, CurrentRaceData.BestLap)
    if CurrentRaceData.BestLap ~= 0 then
        exports.qbx_core:Notify(Lang:t('success.finishedbest', {time = SecondsToClock(CurrentRaceData.TotalTime), best = SecondsToClock(CurrentRaceData.BestLap)}))
    else
        exports.qbx_core:Notify(Lang:t('success.finished', {time = SecondsToClock(CurrentRaceData.TotalTime)}))
    end
    for _, v in pairs(CurrentRaceData.Checkpoints) do
        if v.blip then
            RemoveBlip(v.blip)
            v.blip = nil
        end
        if v.pileleft then
            local coords = v.offset.left
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileleft = nil
        end
        if v.pileright then
            local coords = v.offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileright = nil
        end
    end
    CurrentRaceData.RaceName = nil
    CurrentRaceData.Checkpoints = {}
    CurrentRaceData.Started = false
    CurrentRaceData.CurrentCheckpoint = 0
    CurrentRaceData.TotalLaps = 0
    CurrentRaceData.Lap = 0
    CurrentRaceData.RaceTime = 0
    CurrentRaceData.TotalTime = 0
    CurrentRaceData.BestLap = 0
    CurrentRaceData.RaceId = nil
    RaceData.InRace = false
end

local function IsInRace()
    return RaceData.InRace
end

local function IsInEditor()
    return RaceData.InCreator
end

exports('IsInEditor', IsInEditor)
exports('IsInRace', IsInRace)

-- Events

RegisterNetEvent('qb-lapraces:client:StartRaceEditor', function(RaceName)
    if RaceData.InCreator then
        exports.qbx_core:Notify(Lang:t('error.alreadymaking'), 'error')
        return
    end

    CreatorData.RaceName = RaceName
    RaceData.InCreator = true
    CreatorUI()
    CreatorLoop()
    CheckpointLoop()
    PylonsLoop()
end)

RegisterNetEvent('qb-lapraces:client:UpdateRaceRacerData', function(RaceId, aRaceData)
    if not CurrentRaceData.RaceId or CurrentRaceData.RaceId ~= RaceId then return end

    CurrentRaceData.Racers = aRaceData.Racers
end)

RegisterNetEvent('qb-lapraces:client:JoinRace', function(Data, Laps)
    if RaceData.InRace then
        exports.qbx_core:Notify(Lang:t('error.alreadyinrace'), 'error')
        return
    end

    RaceData.InRace = true
    SetupRace(Data, Laps)
    TriggerServerEvent('qb-lapraces:server:UpdateRaceState', CurrentRaceData.RaceId, false, true)
end)

RegisterNetEvent('qb-lapraces:client:LeaveRace', function()
    exports.qbx_core:Notify(Lang:t('primary.LeaveRace'))
    for _, v in pairs(CurrentRaceData.Checkpoints) do
        if v.blip then
            RemoveBlip(v.blip)
            v.blip = nil
        end
        if v.pileleft then
            local coords = v.offset.left
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileleft = nil
        end
        if v.pileright then
            local coords = v.offset.right
            local Obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 5.0, `prop_offroad_tyres02`, false, false, false)
            DeleteObject(Obj)
            ClearAreaOfObjects(coords.x, coords.y, coords.z, 50.0, 0)
            v.pileright = nil
        end
    end
    CurrentRaceData.RaceName = nil
    CurrentRaceData.Checkpoints = {}
    CurrentRaceData.Started = false
    CurrentRaceData.CurrentCheckpoint = 0
    CurrentRaceData.TotalLaps = 0
    CurrentRaceData.Lap = 0
    CurrentRaceData.RaceTime = 0
    CurrentRaceData.TotalTime = 0
    CurrentRaceData.BestLap = 0
    CurrentRaceData.RaceId = nil
    RaceData.InRace = false
    FreezeEntityPosition(cache.vehicle, false)
end)

RegisterNetEvent('qb-lapraces:client:RaceCountdown', function()
    TriggerServerEvent('qb-lapraces:server:UpdateRaceState', CurrentRaceData.RaceId, true, false)
    if CurrentRaceData.RaceId then
        while Countdown ~= 0 and CurrentRaceData.RaceName do
            if Countdown == 10 then
                exports.qbx_core:Notify(Lang:t('primary.startinten'), 'primary', 2500)
                PlaySound(-1, "slow", "SHORT_PLAYER_SWITCH_SOUND_SET", false, 0, true)
            elseif Countdown <= 5 then
                exports.qbx_core:Notify(Countdown, 'error', 500)
                PlaySound(-1, "slow", "SHORT_PLAYER_SWITCH_SOUND_SET", false, 0, true)
            end
            Countdown -= 1
            FreezeEntityPosition(cache.vehicle, true)
            Wait(1000)
        end
        if CurrentRaceData.RaceName then
            local newCheckpoint = CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1]
            SetNewWaypoint(newCheckpoint.coords.x, newCheckpoint.coords.y)
            exports.qbx_core:Notify(Lang:t('success.start'), 'success', 1000)
            SetBlipScale(newCheckpoint.blip, 1.0)
            FreezeEntityPosition(cache.vehicle, false)
            DoPilePfx()
            CurrentRaceData.Started = true
            Countdown = 10
        else
            FreezeEntityPosition(cache.vehicle, false)
            Countdown = 10
        end
    else
        exports.qbx_core:Notify(Lang:t('error.notinarace'), 'error')
    end
end)

RegisterNetEvent('qb-lapraces:client:PlayerFinishs', function(RaceId, Place, FinisherData)
    if not CurrentRaceData.RaceId or CurrentRaceData.RaceId ~= RaceId then return end

    exports.qbx_core:Notify(Lang:t('error.playerfinished', {firstname = FinisherData.PlayerData.charinfo.firstname, spot = Place}), 'error', 3500)
end)

RegisterNetEvent('qb-lapraces:client:WaitingDistanceCheck', function()
    Wait(1000)
    CreateThread(function()
        while not CurrentRaceData.Started do
            local pos = GetEntityCoords(cache.ped)
            if CurrentRaceData.Checkpoints[1] then
                local cpcoords = CurrentRaceData.Checkpoints[1].coords
                local dist = #(pos - cpcoords)
                if dist > 115.0 then
                    if ToFarCountdown ~= 0 then
                        ToFarCountdown -= 1
                        exports.qbx_core:Notify(Lang:t('error.gobackorkick', {seconds = ToFarCountdown}), 'error', 500)
                    else
                        TriggerServerEvent('qb-lapraces:server:LeaveRace', CurrentRaceData)
                        ToFarCountdown = 10
                        break
                    end
                    Wait(1000)
                else
                    if ToFarCountdown ~= 10 then
                        ToFarCountdown = 10
                    end
                end
            end
            Wait(0)
        end
    end)
end)

-- Threads
CreateThread(function()
    while true do
        local sleep = 1000

        local ped = cache.ped
        local pos = GetEntityCoords(ped)

        if CurrentRaceData.RaceName then
            sleep = 0
            if CurrentRaceData.Started then
                local nextCp = CurrentRaceData.CurrentCheckpoint + 1
                local cp = nextCp > #CurrentRaceData.Checkpoints and 1 or nextCp
                local data = CurrentRaceData.Checkpoints[cp]
                local CheckpointDistance = #(pos - vector3(data.coords.x, data.coords.y, data.coords.z))
                local MaxDistance = GetMaxDistance(CurrentRaceData.Checkpoints[cp].offset)

                if CheckpointDistance < MaxDistance then
                    if CurrentRaceData.TotalLaps == 0 then
                        if nextCp < #CurrentRaceData.Checkpoints then
                            CurrentRaceData.CurrentCheckpoint = nextCp
                            local newCheckPoint = CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1]
                            SetNewWaypoint(newCheckPoint.coords.x, newCheckPoint.coords.y)
                            TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false, 0, true)
                            SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].blip, 0.6)
                            SetBlipScale(newCheckPoint.blip, 1.0)
                        else
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false, 0, true)
                            CurrentRaceData.CurrentCheckpoint = nextCp
                            TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, true)
                            FinishRace()
                        end
                    else
                        if nextCp > #CurrentRaceData.Checkpoints then
                            if CurrentRaceData.Lap + 1 > CurrentRaceData.TotalLaps then
                                DoPilePfx()
                                PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false, 0, true)
                                if CurrentRaceData.RaceTime < CurrentRaceData.BestLap then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                elseif CurrentRaceData.BestLap == 0 then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                end
                                CurrentRaceData.CurrentCheckpoint = nextCp
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, true)
                                FinishRace()
                            else
                                DoPilePfx()
                                PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false, 0, true)
                                if CurrentRaceData.RaceTime < CurrentRaceData.BestLap then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                elseif CurrentRaceData.BestLap == 0 then
                                    CurrentRaceData.BestLap = CurrentRaceData.RaceTime
                                end
                                CurrentRaceData.RaceTime = 0
                                CurrentRaceData.Lap = CurrentRaceData.Lap + 1
                                CurrentRaceData.CurrentCheckpoint = 1
                                local newCheckPoint = CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1]
                                SetNewWaypoint(newCheckPoint.coords.x, newCheckPoint.coords.y)
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                            end
                        else
                            CurrentRaceData.CurrentCheckpoint = nextCp
                            if CurrentRaceData.CurrentCheckpoint ~= #CurrentRaceData.Checkpoints then
                                local newCheckPoint = CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint + 1]
                                SetNewWaypoint(newCheckPoint.coords.x, newCheckPoint.coords.y)
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                                SetBlipScale(CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint].blip, 0.6)
                                SetBlipScale(newCheckPoint.blip, 1.0)
                            else
                                SetNewWaypoint(CurrentRaceData.Checkpoints[1].coords.x, CurrentRaceData.Checkpoints[1].coords.y)
                                TriggerServerEvent('qb-lapraces:server:UpdateRacerData', CurrentRaceData.RaceId, CurrentRaceData.CurrentCheckpoint, CurrentRaceData.Lap, false)
                                SetBlipScale(CurrentRaceData.Checkpoints[#CurrentRaceData.Checkpoints].blip, 0.6)
                                SetBlipScale(CurrentRaceData.Checkpoints[1].blip, 1.0)
                            end
                            DoPilePfx()
                            PlaySound(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false, 0, true)
                        end
                    end
                end
            else
                local data = CurrentRaceData.Checkpoints[CurrentRaceData.CurrentCheckpoint]
                DrawMarker(4, data.coords.x, data.coords.y, data.coords.z + 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.9, 1.5, 1.5, 255, 255, 255, 255, false, true, 0, false, nil, nil, false)
            end
        end

        Wait(sleep)
    end
end)
