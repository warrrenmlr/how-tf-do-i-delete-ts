local source = [=[
getgenv().knifeBotSettings = getgenv().knifeBotSettings or {
    onlyKillTargetUsernames = false,
    targetUsernames = { -- Name not DisplayName
        "",
    },
    maxTeleportStuds = 9.9, -- maximum studs updates can be from each other
    pathfindingInterval = 2, -- raycasting interval (smaller is more laggy but better pathfinding, larger is less laggy but worse pathfinding)
    stayOnGround = true, -- whether or not pathfinding stays on the ground
    playerIgnoreDelay = 2, -- how many seconds it should ignore the target for when you get lagged back
    teleportStability = 15, -- how many updates it should send before stabbing
	teleportDelay = 0, -- how many ms to wait between teleports
    spawnStability = 60, -- how many updates to send when spawning
    performance = true, -- better fps and slightly slower knifebot
    pathfindingMaxTime = 1--0.0833333, -- how long the pathfinding can freeze the game for
}
function LPH_NO_VIRTUALIZE(fuction)
    return fuction
end
LPH_JIT_MAX = LPH_NO_VIRTUALIZE

if getgenv().unload then
	getgenv().unload()
end

local moduleCache
for i, v in getgc(true) do
	if type(v) == "table" and rawget(v, "ScreenCull") and rawget(v, "NetworkClient") then
		moduleCache = v
		break
	end
end

local modules = {}
for name, data in moduleCache do
	if type(data) == "table" then
		modules[name] = data.module
	end
end

local clientEvents
for i, v in getgc(true) do
	if type(v) == "table" and rawget(v, "died") and rawget(v, "smallaward") then
		clientEvents = v
		break
	end
end

local localPlayer = game:GetService("Players").LocalPlayer
local runService = game:GetService("RunService")
local workspace = game:GetService("Workspace")
--local pathfinding = loadstring(readfile("pathfinding.lua"))()
local pathfinding = loadstring(game:HttpGet("https://raw.githubusercontent.com/iRay888/wapus/refs/heads/main/pathfinding.lua"))() -- i didnt make this

local spawnUpdates = 0
local ignoredPlayers = {}
local currentPosition = nil
local currentTeleport = nil

local function ignorePlayer(player)
    table.insert(ignoredPlayers, player)
    task.delay(getgenv().knifeBotSettings.playerIgnoreDelay, function()
        table.remove(ignoredPlayers, table.find(ignoredPlayers, player))
    end)
end

local despawnCount = 0
local lastCorrection = 0
local correctPosition = clientEvents.correctposition
function clientEvents.correctposition(position)
	despawnCount+=1
	print(despawnCount)
    if currentTeleport then
		local clockTime = os.clock()
		
		if clockTime - lastCorrection < 1 then
        	ignorePlayer(currentTeleport.player)
		end

        currentTeleport = nil
		lastCorrection = clockTime
        print("teleport corrected")
    end

    currentPosition = position
    return correctPosition(position)
end

local send = modules.NetworkClient.send
--function modules.NetworkClient:send(name, ...)
modules.NetworkClient.send = LPH_NO_VIRTUALIZE(function(self, name, ...)
    if name == "equip" then
        local slot, time = ...
        return send(self, name, 3, time)
    elseif name == "newbullets" or name == "bullethit" or name == "falldamage" or name == "flaguser" or name == "debug" or name == "logmessage" then
        return
    elseif name == "repupdate" then
        local position, angles, time = ...

        if spawnUpdates < getgenv().knifeBotSettings.spawnStability then
            spawnUpdates += 1
            return send(self, name, ...)
        end

        if currentTeleport and not currentTeleport.complete and currentPosition then
            if currentTeleport.teleported then
                if not currentTeleport.stability then
                    currentTeleport.stability = 0
                else
                    currentTeleport.stability += 1

                    send(self, name, currentPosition, angles, time)
                    if currentTeleport.stability == getgenv().knifeBotSettings.teleportStability then
                        currentTeleport.complete = true
						--currentTeleport.currentTime = nil
                        --correctPosition(currentPosition)
                        local rootPart = modules.CharacterInterface.getCharacterObject():getRealRootPart()
                        rootPart.Position = currentPosition
                        rootPart.Anchored = true
                    end
                end
                
                return
            end

            if currentTeleport.currentTime then
				if currentTeleport.currentTime == 1 then
                	currentTeleport.currentTime = nil
					if currentPosition == nil then
						print("despawn                             NIGGER")
					end
					--return send(self, name, currentPosition, angles, time)
				else
                	currentTeleport.currentTime += 1
				end
            else
                if typeof(currentTeleport.path[currentTeleport.node]) == "Vector3" then
					currentPosition = currentTeleport.path[currentTeleport.node]
                	send(self, name, currentPosition, angles, time)
				else
					print("type mismatch")
					print(typeof(currentTeleport.path[currentTeleport.node]), currentTeleport.path[currentTeleport.node])
				end
                
				repeat currentTeleport.node += 1 until (typeof(currentTeleport.path[currentTeleport.node]) == "Vector3") or (currentTeleport.node > currentTeleport.lastNode)
                
				if typeof(currentTeleport.path[currentTeleport.node]) == "Vector3" then
                    currentPosition = currentTeleport.path[currentTeleport.node]
                    send(self, name, currentPosition, angles, time)
                    --send(self, name, currentPosition + Vector3.yAxis * 0.01, angles, time + 0.001)
                else
                    currentTeleport.teleported = true
                end
                currentTeleport.currentTime = 1 -- time


                if (currentTeleport.node == currentTeleport.lastNode) or (not currentPosition) then
                    currentTeleport.teleported = true
                end
            end

            return
        end

        currentPosition = position
    end

    return send(self, name, ...)
end)

local sentSpawn = modules.CharacterInterface.spawn
function modules.CharacterInterface.spawn(player)
	currentPosition = nil
    currentTeleport = nil
    spawnUpdates = 0
	despawnCount = 0
	return sentSpawn(player)
end

local receivedSpawn = clientEvents.spawn
function clientEvents.spawn(position, direction, uniqueIds, loadoutData, attachmentData)
    currentTeleport = nil
    if getgenv().knifeBotSettings.spawnStability == 0 then
	    currentPosition = position
    end

	return receivedSpawn(position, direction, uniqueIds, loadoutData, attachmentData)
end

local function getClosestPlayers(position)
    local closestCharacters
    local characterData

    modules.ReplicationInterface.operateOnAllEntries(function(player, entry)
        local character = entry._thirdPersonObject and entry._thirdPersonObject:getCharacterHash()

        if entry._receivedPosition and entry._velspring.t and character and player.Team ~= localPlayer.Team and character.Head and not table.find(ignoredPlayers, player) then
            if (not getgenv().knifeBotSettings.onlyKillTargetUsernames) or table.find(getgenv().knifeBotSettings.targetUsernames, player.Name) then
                local playerDistance = (character.Head.Position - position).Magnitude
                local playerData = {character, playerDistance}
                
                if not characterData then
                    characterData = {playerData}
                    closestCharacters = {entry}
                else
                    for charIndex = #characterData, 1, -1 do
                        if playerDistance > characterData[charIndex][2] then
                            table.insert(characterData, charIndex + 1, playerData)
                            table.insert(closestCharacters, charIndex + 1, entry)
                            break
                        end
                    end
        
                    if not table.find(characterData, playerData) then
                        table.insert(characterData, 1, playerData)
                        table.insert(closestCharacters, 1, entry)
                    end
                end
            end
        end
    end)

    return closestCharacters
end

function waitHeartbeat()
    return getgenv().knifeBotSettings.performance and runService.Heartbeat:Wait()
end

local lastFinish = 0
local pathfindingParams = {
    step = getgenv().knifeBotSettings.pathfindingInterval,
    trials = 1/0,
    weighting = 400,
    mindist = 20,
    maxtime = getgenv().knifeBotSettings.pathfindingMaxTime,
}
--function knifeBotStep()
local knifeBotStep = LPH_NO_VIRTUALIZE(function()
    local canSkip = false

	if (modules.CharacterInterface.isAlive() or modules.CharacterInterface.isSpawning()) and not modules.RoundSystemClientInterface.roundLock and currentPosition and ((getgenv().knifeBotSettings.teleportDelay == 0) or (os.clock() - lastFinish > getgenv().knifeBotSettings.teleportDelay * 0.001)) then
        local closestEntries = getClosestPlayers(currentPosition)
        local targetEntry
		
        if closestEntries then
            for entryIndex = 1, #closestEntries do
                local entry = closestEntries[entryIndex]
                
                if entry:isAlive() and entry._receivedPosition then
                    local position = entry._receivedPosition
                    local pathfindFunc = getgenv().knifeBotSettings.stayOnGround and pathfinding.floorAStar or pathfinding.vadAStar
					local start = currentPosition
                    local result, data = pathfindFunc({
                        start = start,
                        goal = position,
                        parameters = pathfindingParams
                    })
					--local result, data = pathfinding.floorBestFirstSearch(origin, target, param)
                    
                    if result == true then
                        print("path found")
                        local movements = pathfinding.optimizePath(data.waypoints, getgenv().knifeBotSettings.maxTeleportStuds)

						if movements then
							--pathfinding.visualizePath(movements, Color3.new(1, 0, 0))
							--unload()
							--table.insert(movements, 1, start)
							targetEntry = entry
							currentTeleport = {
								--currentTime = 1,
								player = entry._player,
								lastNode = #movements,
								path = movements,
								node = 1
							}
							break
						else
							print("no path :(")
							waitHeartbeat()
						end
                    else
                        print("no path :(")
                        waitHeartbeat()
                    end
                end
            end
        end

        if targetEntry then
            canSkip = true
            repeat runService.Heartbeat:Wait() until (not currentTeleport or currentTeleport.complete)
			lastFinish = os.clock()

            if currentTeleport then
                ignorePlayer(targetEntry._player)

                for _ = 1, 3 do
					task.wait(0.05)

					if targetEntry:isAlive() and targetEntry._receivedPosition then
						modules.NetworkClient:send("stab")
						modules.NetworkClient:send("knifehit", targetEntry._player, "Head", targetEntry._receivedPosition, modules.NetworkClient.getTime())
					end
                end
				
				task.wait(0.05)
                local character = modules.CharacterInterface.getCharacterObject()
				if character then
					character:getRealRootPart().Anchored = false
				end
                print("stabbed", targetEntry._player)
                currentTeleport = nil
            end
        end
    end
    
    if canSkip then
        waitHeartbeat()
    else
        runService.Heartbeat:Wait()
    end
end)

local stop = false
getgenv().unload = function()
	clientEvents.correctposition = correctPosition
	modules.NetworkClient.send = send
	modules.CharacterInterface.spawn = sentSpawn
	clientEvents.spawn = receivedSpawn
	stop = true
end

task.spawn(function()
while true do -- pro
    knifeBotStep()

	if stop then
		break
	end
end
end)
]=]

local environment = identifyexecutor and identifyexecutor() or ""

if getfflag and string.find(string.lower(tostring(getfflag("DebugRunParallelLuaOnMainThread"))), "true") and not executed then
    loadstring(source)()
elseif string.find(environment, "AWP") ~= nil and not executed then
    for _, v in getactors() do
        run_on_actor(v, [[
            for _, func in getgc(false) do
                if type(func) == "function" and islclosure(func) and debug.getinfo(func).name == "require" and string.find(debug.getinfo(func).source, "ClientLoader") then
                    ]] .. source .. [[
                    break
                end
            end
        ]])
    end
elseif environment == "Wave" and not executed then
    run_on_actor(getdeletedactors()[1], source)
elseif environment == "Nihon" and not executed then
    for _, actor in getactorthreads() do
        run_on_thread(actor, [[
            for _, func in getgc(false) do
                if type(func) == "function" and islclosure(func) and debug.getinfo(func).name == "require" and string.find(debug.getinfo(func).source, "ClientLoader") then
                    ]] .. source .. [[
                    break
                end
            end
        ]])
    end
else
    queue_on_teleport(game:HttpGet("https://raw.githubusercontent.com/iRay888/wapus/refs/heads/main/hook.lua") .. "task.wait(5);" .. source)
    setfflag("DebugRunParallelLuaOnMainThread", "True")
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
end
getgenv().executed = true
