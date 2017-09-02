
local obj = { name = "backup" }
obj.__index = obj

local PROGRESS_PATTERN = [[%[([%d%:]+)%]%s+([%d%.]+)%%%s+]]

function obj.new(spoon)
    local self = { spoon = spoon, log = spoon.log, exec = spoon.exec }
    setmetatable(self, obj)
    return self
end

function obj:start()
    if self:active() then
        self.spoon:warn("Backup is already running")
        return
    end
    if self.logFile then
        os.remove(self.logFile)
    end
    local args = self:buildArgs()
    local onComplete = function (...) return self:onTaskComplete(...) end
    local onOutput = function (...) return self:onTaskOutput(...) end
    self.task, self.terminate, self.logFile = self.exec:newResticTask(
        args, onComplete, onOutput, true)
    self.task:start()
    self.log.df("restic %s started", obj.name)
end

function obj:active()
    return self.task ~= nil
end

function obj:stop()
    if self:active() then
        local terminate = self.terminate
        self.terminate = nil
        terminate()
    end
end

function obj:buildArgs()
    local args = { obj.name, "-x" }
    for i, pattern in ipairs(self.spoon:getExclusionPatterns()) do
        table.insert(args, "-e")
        table.insert(args, pattern)
    end
    for i, path in ipairs(self.spoon:getBackupDirs()) do
        table.insert(args, path)
    end
    return args
end

function obj:onTaskComplete(exitCode, stdOut, stdErr)
    self.task = nil
    self.terminate = nil
    self.log.df("restic %s exited with code %s", obj.name, exitCode)
    if exitCode ~= 0 and self.terminate ~= nil then
        self.spoon:warn(stdOut .. stdErr)
    end
    self.spoon:updateProgress()
    self.spoon:refreshLatestBackup()
end

function obj:onTaskOutput(task, stdOut)
    local elapsed, percent = stdOut:match(PROGRESS_PATTERN)
    self.spoon:updateProgress(elapsed, tonumber(percent))
    return true
end

function obj:getLogFile()
    return self.logFile
end

return obj
