
local obj = { command = "restic backup" }
obj.__index = obj

local SCANNED_PATTERN = "scanned %d+ directories"
local PERCENT_PATTERN = "%s+([%d%.]+%%)%s+"

function obj.new(spoon, log)
    local self = { spoon = spoon, log = log }
    setmetatable(self, obj)
    return self
end

function obj:start()
    if self.task then
        self.spoon:warn("Backup is already running")
        return
    end
    local path = self.spoon:getResticPath()
    local env = self.spoon:buildResticEnv()
    local onComplete = function (...) return self:onTaskComplete(...) end
    local onOutput = function (...) return self:onTaskOutput(...) end
    self.output = {}
    self.task = hs.task.new(path, onComplete, onOutput, self:buildArgs())
    self.task:setEnvironment(env)
    self.task:start()
    self.spoon:updateProgress("0.00%", "initializing")
    self.log.df("%q started", obj.command)
end

function obj:stop()
    if self.task and self.task:isRunning() then
        self.task:terminate()
    end
end

function obj:buildArgs()
    local args = { "backup", "--one-file-system" }
    for i, path in ipairs(self.spoon:getBackupDirs()) do
        table.insert(args, path)
    end
    return args
end

function obj:onTaskComplete(exitCode, stdOut, stdErr)
    self.task = nil
    self.log.df("%q exited with code %s", obj.command, exitCode)
    if exitCode ~= 0 then
        self.spoon:warn(stdOut .. stdErr)
    end
    self.spoon:updateProgress()
end

function obj:onTaskOutput(task, stdOut, stdErr)
    table.insert(self.output, stdOut .. stdErr)
    if stdOut:find(SCANNED_PATTERN) then
        self.log.df("backup initial scanning complete")
        self:queryProgress(task)
    end
    local found, _, percent = stdOut:find(PERCENT_PATTERN)
    if found then
        self.log.df("current backup progress is %s", percent)
        self.spoon:updateProgress(percent)
        hs.timer.doAfter(15, function ()
            self:queryProgress(task)
        end)
    end
    return true
end

function obj:queryProgress(task)
    if task:isRunning() then
        local pid = "" .. task:pid()
        self.log.df("sending USR1 to pid %s", pid)
        hs.task.new("/bin/kill", nil, { "-USR1", pid }):start()
    end
end

function obj:showLog()
    if self.output then
        local task = hs.task.new("/usr/bin/open", nil, { "-f" })
        task:setInput(table.concat(self.output))
        task:start()
    else
        self.spoon:warn("No backup logs available")
    end
end

return obj
