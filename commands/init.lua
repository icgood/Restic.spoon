
local obj = { command = "restic init" }
obj.__index = obj

function obj.new(spoon, log)
    local self = { spoon = spoon, log = log }
    setmetatable(self, obj)
    return self
end

function obj:create()
    if self.task then
        return
    end
    local path = self.spoon:getResticPath()
    local env = self.spoon:buildResticEnv()
    local complete = function (...) return self:taskComplete(...) end
    self.task = hs.task.new(path, complete, { "init" })
    self.task:setEnvironment(env)
    self.task:start()
    self.log.df("%q started", obj.command)
end

function obj:taskComplete(exitCode, stdOut, stdErr)
    self.task = nil
    self.log.df("%q exited with code %s", obj.command, exitCode)
    if exitCode == 0 then
        self.spoon:refreshLatestBackup()
    else
        self.spoon:warn(stdOut .. stdErr)
    end
end

return obj
