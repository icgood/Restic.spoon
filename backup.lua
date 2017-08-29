
local obj = {}
obj.__index = obj

local SCANNED_PATTERN = "scanned %d+ directories"
local PROGRESS_PATTERN = "%[%d+:%d+%]%s+(%g+%s+%g+%s+%g+)"

function obj.new(spoon)
    local self = { spoon = spoon }
    setmetatable(self, obj)
    return self
end

function obj:start()
    if self.task then
        hs.alert.show("Backup is already running...")
        return
    end
    local path = self.spoon:getResticPath()
    local env = self.spoon:getResticEnv()
    local backupDir = self.spoon:getBackupDir()
    local complete = function (...) return self:taskComplete(...) end
    local output = function (...) return self:taskOutput(...) end
    local args = { "backup", "--one-file-system", backupDir }
    self.task = hs.task.new(path, complete, output, args)
    self.task:setEnvironment(env)
    self.task:start()
    self.spoon:setProgress("initializing")
end

function obj:stop()
    if self.task then
        self.task:terminate()
    end
end

function obj:taskComplete(exitCode, stdOut, stdErr)
    self.task = nil
    if exitCode ~= 0 then
        local output = stdOut .. stdErr
        if output ~= "" then
            hs.alert.show(output)
        end
    end
    self.spoon:setProgress(nil)
end

function obj:taskOutput(task, stdOut, stdErr)
    if stdOut:find(SCANNED_PATTERN) then
        self:startProgressTimer(task)
    else
        local progress = stdOut:match(PROGRESS_PATTERN)
        if progress then
            self.spoon:setProgress(progress)
            hs.timer.doAfter(10, function ()
                self:startProgressTimer(task)
            end)
        end
    end
    return true
end

function obj:startProgressTimer(task)
    if task:isRunning() then
        local pid = "" .. task:pid()
        hs.task.new("/bin/kill", nil, { "-USR1", pid }):start()
    end
end

function obj:handleJson(json)
    local latest = 0
    local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"
    for i, snapshot in ipairs(json) do
        local xyear, xmonth, xday, xhour, xminute, xseconds, xmillies, xoffset =
            snapshot.time:match(pattern)
        local time = os.time({year = xyear, month = xmonth, day = xday, hour = xhour,
            min = xminute, sec = xseconds})
        if time > latest then
            latest = time
        end
    end
    if latest > 0 then
        self.spoon:setLatestBackup(latest)
    end
end

return obj
