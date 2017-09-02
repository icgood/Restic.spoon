
local obj = { name = "snapshots" }
obj.__index = obj

local TIME_PATTERN = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"

function obj.new(spoon, callback)
    local self = { spoon = spoon, log = spoon.log, exec = spoon.exec, callback = callback }
    setmetatable(self, obj)
    return self
end

function obj:start()
    if self:active() then
        return
    end
    local args = { obj.name, "--json" }
    local onComplete = function (...) return self:onTaskComplete(...) end
    self.task = self.exec:newResticTask(args, onComplete)
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
        local json = hs.json.decode(stdOut) or {}
        self:handleJson(json)
    else
        self.spoon:warn(stdOut .. stdErr)
        self.callback("failure")
    end
end

function obj:handleJson(json)
    local latest = 0
    for i, snapshot in ipairs(json) do
        local xyear, xmonth, xday, xhour, xminute, xseconds, xmillies, xoffset =
            snapshot.time:match(TIME_PATTERN)
        local time = os.time({year = xyear, month = xmonth, day = xday, hour = xhour,
            min = xminute, sec = xseconds})
        self.log.df("found snapshot of %s at %s", snapshot.hostname, time)
        if time > latest then
            latest = time
        end
    end
    self.log.df("found most recent snapshot at %s", latest)
    self.callback(latest)
end

return obj
