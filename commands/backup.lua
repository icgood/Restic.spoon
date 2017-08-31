
local obj = { name = "backup", canSudo = true }
obj.__index = obj

local PROGRESS_PATTERN = [[%[([%d%:]+)%]%s+([%d%.]+)%%%s+]]

function obj.new(spoon, log)
    local self = { spoon = spoon, log = log }
    setmetatable(self, obj)
    return self
end

function obj:start()
    if self:active() then
        self.spoon:warn("Backup is already running")
        return
    end
    self.output = {}
    local args = self:buildArgs()
    local onComplete = function (...) return self:onTaskComplete(...) end
    local onOutput = function (...) return self:onTaskOutput(...) end
    self.task = self.spoon:newResticTask(self, args, onComplete, onOutput)
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

function obj:buildArgs()
    local args = { "--one-file-system" }
    for i, path in ipairs(self.spoon:getBackupDirs()) do
        table.insert(args, path)
    end
    return args
end

function obj:onTaskComplete(exitCode)
    self.task = nil
    self.log.df("restic %s exited with code %s", obj.name, exitCode)
    self.spoon:updateProgress()
    self.spoon:refreshLatestBackup()
end

function obj:onTaskOutput(task, stdOut, stdErr)
    table.insert(self.output, stdOut .. stdErr)
    if stdErr and stdErr ~= "" then
        self.spoon:warn(stdErr)
    end
    local elapsed, percent = stdOut:match(PROGRESS_PATTERN)
    self.spoon:updateProgress(elapsed, tonumber(percent))
    return true
end

function obj:getLog()
    return table.concat(self.output or {})
end

return obj
