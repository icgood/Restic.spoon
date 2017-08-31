
local obj = { name = "init" }
obj.__index = obj

function obj.new(spoon, log)
    local self = { spoon = spoon, log = log }
    setmetatable(self, obj)
    return self
end

function obj:create()
    if self:active() then
        return
    end
    local onComplete = function (...) return self:onTaskComplete(...) end
    self.task = self.spoon:newResticTask(self, {}, onComplete)
    self.task:start()
    self.log.df("restic %s started", obj.name)
end

function obj:active()
    return self.task ~= nil
end

function obj:onTaskComplete(exitCode, stdOut, stdErr)
    self.task = nil
    self.log.df("restic %s exited with code %s", obj.name, exitCode)
    if exitCode == 0 then
        self.spoon:refreshLatestBackup()
    else
        self.spoon:warn(stdOut .. stdErr)
    end
end

return obj
