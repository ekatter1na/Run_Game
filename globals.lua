local M = {}

M.unlockedLevel = 1

function M.loadProgress()
    local json = require("json")
    local path = system.pathForFile("save.json", system.DocumentsDirectory)
    local file = io.open(path, "r")
    if file then
        local contents = file:read("*a")
        local data = json.decode(contents)
        if data then
            M.unlockedLevel = data.unlockedLevel or 1
        end
        file:close()
    end
end

function M.saveProgress()
    local json = require("json")
    local path = system.pathForFile("save.json", system.DocumentsDirectory)
    local file = io.open(path, "w")
    if file then
        file:write(json.encode({unlockedLevel = M.unlockedLevel}))
        file:close()
    end
end

return M