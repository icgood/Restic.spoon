
local obj = {}
obj.__index = obj

function obj.new(spoon)
    local self = { spoon = spoon }
    setmetatable(self, obj)
    return self
end

function obj:refresh()
    if self.task then
        return
    end
    local path = self.spoon:getResticPath()
    local env = self.spoon:getResticEnv()
    self.task = hs.task.new(path, function (exitCode, stdOut, stdErr)
        locked = false
        if exitCode == 0 then
            local json = hs.json.decode(stdOut)
            self:handleJson(json)
        else
            hs.alert.show(stdErr)
        end
    end, { "snapshots", "--json" })
    self.task:setEnvironment(env)
    self.task:start()
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
