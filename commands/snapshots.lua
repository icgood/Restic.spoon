
local obj = { command = "restic snapshots" }
obj.__index = obj

local TIME_PATTERN = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)"

function obj.new(spoon, log)
    local self = { spoon = spoon, log = log }
    setmetatable(self, obj)
    return self
end

function obj:refresh()
    if self.task then
        return
    end
    local path = self.spoon:getResticPath()
    local env = self.spoon:buildResticEnv()
    local complete = function (...) return self:taskComplete(...) end
    self.task = hs.task.new(path, complete, { "snapshots", "--json" })
    self.task:setEnvironment(env)
    self.task:start()
    self.log.df("%q started", obj.command)
end

function obj:taskComplete(exitCode, stdOut, stdErr)
    self.task = nil
    self.log.df("%q exited with code %s", obj.command, exitCode)
    if exitCode == 0 then
        local json = hs.json.decode(stdOut) or {}
        self:handleJson(json)
    else
        self.spoon:warn(stdOut .. stdErr)
        self.spoon:updateLatestBackup("failure")
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
    self.spoon:updateLatestBackup(latest)
end

return obj
