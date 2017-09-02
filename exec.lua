
local obj = {}
obj.__index = obj

local NOOP = function () end

function obj.new(spoon)
    local self = { spoon = spoon, log = spoon.log }
    setmetatable(self, obj)
    return self
end

local function quote(str)
    str = string.gsub(str, [[%\]], [[\\]])
    str = string.gsub(str, [[%"]], [[\"]])
    return '"' .. str .. '"'
end

local function rstrip(str)
    return string.gsub(output, "[%\r%\n]+$", "")
end

local function join(list)
    return table.concat(list, " ")
end

local function append(dest, src)
    return table.move(src, 1, #src, #dest + 1, dest)
end

local function makeTempFile()
    local output, success = hs.execute("mktemp")
    if not success then
        error("mktemp failed: " .. output)
    end
    return string.gsub(output, "[%\r%\n]+$", "")
end

local function tailFile(path, onOutput)
    local args = { "-c", "tail -f " .. path }
    local task = hs.task.new("/bin/sh", NOOP, onOutput, args)
    task:start()
    return task
end

local function buildResticEnv(self)
    local env = {
        RESTIC_REPOSITORY = self.spoon:getRepository(),
        RESTIC_PASSWORD = self.spoon:getPassword(),
    }
    for key, val in pairs(self.spoon:getEnvironment()) do
        env[key] = val
    end
    if env.RESTIC_REPOSITORY:sub(1, 3) == "s3:" and not env.AWS_ACCESS_KEY_ID then
        error("Must call :setS3Credentials() first")
    end
    return env
end

function obj:newTask(shell, onComplete, asAdmin)
    local setCommand = [[set cmd to ]] .. quote(join(shell))
    local doShellScript = [[do shell script "sh -c " & quoted form of cmd]]
    if asAdmin then
        doShellScript = doShellScript .. [[ with administrator privileges]]
    end
    local args = { "-e", setCommand, "-e", doShellScript }
    return hs.task.new("/usr/bin/osascript", onComplete, args)
end

function obj:newLongTask(shell, onComplete, onOutput, asAdmin)
    local pidFile = makeTempFile()
    local outputFile = makeTempFile()
    local tailOutput = tailFile(outputFile, onOutput)
    local task

    shell = append({ "echo $$ >", pidFile, "; exec 1>", outputFile, "; exec" }, shell)
    task = self:newTask(shell, function (...)
        tailOutput:terminate()
        os.remove(pidFile)
        return onComplete(...)
    end, asAdmin)

    local terminate = function ()
        local shell = { "cat", pidFile, "| xargs kill" }
        local task = self:newTask(shell, NOOP, asAdmin)
        task:start()
    end
    return task, terminate, outputFile
end

function obj:newResticTask(args, onComplete, onOutput, asAdmin)
    local restic = self.spoon:getResticPath()
    local shell = append({ restic }, args)
    local task, terminate, outputFile

    if onOutput then
        task, terminate, outputFile = self:newLongTask(shell, onComplete, onOutput, asAdmin)
    else
        task = self:newTask(shell, onComplete, asAdmin)
    end
    task:setEnvironment(buildResticEnv(self))
    return task, terminate, outputFile
end

return obj
