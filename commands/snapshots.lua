
local obj = { name = "snapshots" }
obj.__index = obj

local TIME_PATTERN = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"

function obj.new(spoon, log)
    local self = { spoon = spoon, log = log }
    setmetatable(self, obj)
    return self
end

function obj:refresh(callback)
    if self:active() then
        return
    end
    local args = { "--json" }
    local onComplete = function (...) return self:onTaskComplete(callback, ...) end
    self.task = self.spoon:newResticTask(self, args, onComplete)
    self.task:start()
    self.log.df("restic %s started", obj.name)
end

function obj:active()
    return self.task ~= nil
end

function obj:onTaskComplete(callback, exitCode, stdOut, stdErr)
    self.task = nil
    self.log.df("restic %s exited with code %s", obj.name, exitCode)
    if exitCode == 0 then
        local json = hs.json.decode(stdOut) or {}
        self:handleJson(callback, json)
    else
        self.spoon:warn(stdOut .. stdErr)
        callback("failure")
    end
end

function obj:handleJson(callback, json)
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
    callback(latest)
end

return obj
