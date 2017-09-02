
local obj = { name = "init" }
obj.__index = obj

function obj.new(spoon)
    local self = { spoon = spoon, log = spoon.log, exec = spoon.exec }
    setmetatable(self, obj)
    return self
end

function obj:start()
    if self:active() then
        return
    end
    local onComplete = function (...) return self:onTaskComplete(...) end
    self.task = self.exec:newResticTask({ obj.name }, onComplete)
    self.task:start()
    self.log.df("restic %s started", obj.name)
end

function obj:active()
    return self.task ~= nil
end

function obj:stop()
    if self:active() and self.task:isRunning() then
        self.task:terminate()
    end
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
