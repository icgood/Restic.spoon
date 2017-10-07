--- === Restic ===
---
--- Manage [restic](https://restic.github.io/) backups in the menu bar.
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Restic"
obj.version = "1.3"
obj.author = "Ian Good <icgood@gmail.com>"
obj.homepage = "https://github.com/icgood/Restic.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

local function getIcons()
    local black = hs.image.imageFromPath(obj.spoonPath .. "/resources/restic.png")
    local red = hs.image.imageFromPath(obj.spoonPath .. "/resources/restic-red.png")
    black:size({ w = 16, h = 16 })
    red:size({ w = 16, h = 16 })
    return black, red
end

local function doLuaFile(file)
    return dofile(obj.spoonPath .. "/" .. file)
end

local function setSetting(self, name, value)
    self.settings[name] = value
    return self
end

local function getSetting(self, name, default)
    local val = self.settings[name]
    if val ~= nil then
        return val
    elseif default ~= nil then
        return default
    else
        error("Must call :set" .. name .. "() first")
    end
end

local function getTimeStr(time)
    if time == 0 then
        return "none"
    else
        return os.date("%b %d, %I:%M %p", time)
    end
end

local function showHelp()
    hs.doc.hsdocs.help("spoon." .. obj.name)
end

local function buildMenu(self)
    local menu = {}
    if not self.latestBackup then
        table.insert(menu, { title = "Latest Backup: checking...", disabled = true })
    elseif self.latestBackup == "failure" then
        table.insert(menu, { title = "Failed to find latest backup!", disabled = true })
        table.insert(menu, { title = "-" })
        table.insert(menu, { title = "Create repository", fn = function () self:createRepo() end })
        table.insert(menu, { title = "Refresh", fn = function () self:refreshLatestBackup() end })
    else
        local timeStr = getTimeStr(self.latestBackup)
        table.insert(menu, { title = "Latest Backup: " .. timeStr, disabled = true })
        if self.stale and type(self.latestBackup) == "number" then
            local daysOld = (hs.timer.secondsSinceEpoch() - self.latestBackup) / hs.timer.days(1)
            local title = string.format("Backup is %.0f days old!", daysOld)
            table.insert(menu, { title = title, disabled = true})
        end
        table.insert(menu, { title = "-" })
        if self.backup:active() then
            table.insert(menu, { title = "Stop Backup", fn = function () self:stopBackup() end })
            if self.elapsed then
                table.insert(menu, { title = "Elapsed: " .. self.elapsed, disabled = true })
            end
            if self.percent then
                local percentStr = string.format("%.2f%%", self.percent)
                table.insert(menu, { title = "Percent: " .. percentStr, disabled = true })
            end
        else
            table.insert(menu, { title = "Backup Now", fn = function () self:startBackup() end })
        end
    end
    table.insert(menu, { title = "-" })
    table.insert(menu, { title = "Show backup log", fn = function () self:showBackupLog() end })
    table.insert(menu, { title = "Help", fn = function () showHelp() end })
    return menu
end

function obj:init()
    self.settings = {}
    self:loadSettings(nil, true)

    self.blackIcon, self.redIcon = getIcons()
    self.log = hs.logger.new(obj.name)
    self.exec = doLuaFile("exec.lua").new(self)
    self.initRepo = doLuaFile("commands/init.lua").new(self)
    self.backup = doLuaFile("commands/backup.lua").new(self)
    self.snapshots = doLuaFile("commands/snapshots.lua").new(self, function (val)
        self.latestBackup = val
        self:checkBackupAge()
    end)

    self.menuBarItem = hs.menubar.new(false)
    self.menuBarItem:setIcon(self.blackIcon)
    self.menuBarItem:setMenu(function () return buildMenu(self) end)
end

--- Restic:start()
--- Method
--- Starts Restic
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Restic object
function obj:start()
    if not self:active() then
        self.log.f("starting %s menu bar", obj.name)
        self:updateProgress()
        self:refreshLatestBackup()
        self.menuBarItem:returnToMenuBar()
    end
    return self
end

--- Restic:stop()
--- Method
--- Stops Restic
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Restic object
function obj:stop()
    if self:active() then
        self.log.f("stopping %s menu bar", obj.name)
        self.menuBarItem:removeFromMenuBar()
        self.backup:stop()
    end
    return self
end

--- Restic:setResticPath()
--- Method
--- Specifies the full path to the restic executable
---
--- Parameters:
---  * path - a string containing the full path
---
--- Returns:
---  * The Restic object
function obj:setResticPath(path)
    local absPath = hs.fs.pathToAbsolute(path)
    if not absPath then
        error("Path does not exist: " .. path)
    end
    self.log.df("set restic path to %q", absPath)
    return setSetting(self, "ResticPath", absPath)
end

function obj:getResticPath()
    return getSetting(self, "ResticPath", "restic")
end

--- Restic:setRepository()
--- Method
--- Specifies the restic repository string, as described in
--- [the documentation(https://restic.readthedocs.io/en/stable/manual.html#initialize-a-repository)
---
--- Parameters:
---  * repo - a string containing the repository info
---
--- Returns:
---  * The Restic object
function obj:setRepository(repo)
    self.log.df("set restic repository to %q", repo)
    return setSetting(self, "Repository", repo)
end

function obj:getRepository()
    return getSetting(self, "Repository")
end

--- Restic:setPassword()
--- Method
--- Specifies the restic repository password
---
--- Parameters:
---  * password - a string containing the repository password
---
--- Returns:
---  * The Restic object
function obj:setPassword(password)
    self.log.df("set restic password to %q", "***")
    return setSetting(self, "Password", password)
end

function obj:getPassword()
    return getSetting(self, "Password")
end

--- Restic:setEnvironment()
--- Method
--- Specifies the environment variables for executing restic, including any
--- necessary credentials for remote repositories such as S3
---
--- Parameters:
---  * env - table of environment variables
---
--- Returns:
---  * The Restic object
function obj:setEnvironment(env)
    self.log.df("set restic environment")
    return setSetting(self, "Environment", env)
end

function obj:getEnvironment()
    return getSetting(self, "Environment", {})
end

--- Restic:setS3Credentials()
--- Method
--- Specifies the S3 credentials used when remote repositories of that type
---
--- Parameters:
---  * accessKey - string of the S3 access key
---  * secretKey - string of the S3 secret key
---
--- Returns:
---  * The Restic object
function obj:setS3Credentials(accessKey, secretKey)
    local env = self:getEnvironment()
    env.AWS_ACCESS_KEY_ID = accessKey
    env.AWS_SECRET_ACCESS_KEY = secretKey
    return self:setEnvironment(env)
end

--- Restic:setBackupDirs()
--- Method
--- Specifies the directories to backup
---
--- Parameters:
---  * ... - one or more directory paths
---
--- Returns:
---  * The Restic object
function obj:setBackupDirs(...)
    local directories = { ... }
    for i, path in ipairs(directories) do
        local absPath = hs.fs.pathToAbsolute(path)
        if not absPath then
            error("Path does not exist: " .. path)
        elseif absPath ~= path then
            directories[i] = absPath
        end
    end
    self.log.df("set backup directories to %s", table.concat(directories, ", "))
    return setSetting(self, "BackupDirs", directories)
end

function obj:getBackupDirs()
    return getSetting(self, "BackupDirs", { "/" })
end

--- Restic:setExclusionPatterns()
--- Method
--- Specifies the patterns to exclude from backup
---
--- Parameters:
---  * ... - one or more exclusion patterns
---
--- Returns:
---  * The Restic object
function obj:setExclusionPatterns(...)
    local patterns = { ... }
    self.log.df("set exclusion patterns to %s", table.concat(patterns, ", "))
    return setSetting(self, "ExclusionPatterns", patterns)
end

function obj:getExclusionPatterns()
    return getSetting(self, "ExclusionPatterns", {})
end

--- Restic:setReminderDelay()
--- Method
--- Specifies the reminder delay after the last backup
---
--- Parameters:
---  * days - duration in days
---
--- Returns:
---  * The Restic object
function obj:setReminderDelay(days)
    self.log.df("set reminder delay to %s days", days)
    setSetting(self, "ReminderDelay", days)
    self:checkBackupAge()
    return self
end

function obj:getReminderDelay()
    return getSetting(self, "ReminderDelay", 10)
end

--- Restic:saveSettings()
--- Method
--- Saves the current settings to a file
---
--- Parameters:
---  * filename - path to settings file, defaults to `~/.restic.spoon`
---
--- Returns:
---  * The Restic object
function obj:saveSettings(filename)
    if not filename then
        filename = hs.fs.pathToAbsolute("~") .. "/.restic.spoon"
    end
    local write = hs.json.encode(self.settings, true)
    local file, err = io.open(filename, "w")
    if not file then
        error(err)
    end
    file:write(write)
    file:close()
    return self
end

--- Restic:loadSettings()
--- Method
--- Loads settings from a file
---
--- Parameters:
---  * filename - path to settings file, defaults to `~/.restic.spoon`
---
--- Returns:
---  * The Restic object
function obj:loadSettings(filename, noPanic)
    if not filename then
        filename = hs.fs.pathToAbsolute("~") .. "/.restic.spoon"
    end
    local file, err = io.open(filename, "r")
    if not file and not noPanic then
        error(err)
    end
    local json = file:read("a")
    file:close()
    self.settings = hs.json.decode(json)
    return self
end

--- Restic:createRepo()
--- Method
--- Initializes a new restic repository with `restic init`
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Restic object
function obj:createRepo()
    self.log.f("creating new restic repo in %q", self:getRepository())
    self.latestBackup = nil
    self.initRepo:start()
    return self
end

--- Restic:startBackup()
--- Method
--- Begins a new restic backup
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Restic object
function obj:startBackup()
    self.log.f("starting a new restic backup to %q", self:getRepository())
    self.backup:start()
    return self
end

--- Restic:stopBackup()
--- Method
--- Stops the currently-running restic backup
---
--- Parameters:
---  * None
---
--- Returns:
---  * The Restic object
function obj:stopBackup()
    self.backup:stop()
    return self
end

--- Restic:showBackupLog()
--- Method
--- Shows the current contents of the backup log in TextEdit
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:showBackupLog()
    local logFile = self.backup:getLogFile()
    if logFile then
        hs.task.new("/usr/bin/open", nil, { "-t", logFile }):start()
    else
        self:warn("No backup logs available")
    end
end

function obj:active()
    return self.menuBarItem:isInMenubar()
end

function obj:refreshLatestBackup()
    self.snapshots:start()
end

function obj:updateProgress(elapsed, percent)
    self.elapsed = elapsed
    self.percent = percent
    if percent then
        self.menuBarItem:setTitle(string.format("%.0f%%", percent))
    else
        self.menuBarItem:setTitle(nil)
    end
end

function obj:checkBackupAge()
    if self.reminder ~= nil then
        self.reminder:stop()
    end

    self.stale = nil
    if not self.latestBackup then
        self.menuBarItem:setIcon(self.blackIcon)
    elseif self.latestBackup == "failure" then
        self.menuBarItem:setIcon(self.redIcon, false)
    elseif self.latestBackup == "none" then
        self.menuBarItem:setIcon(self.redIcon, false)
    else
        local delay = hs.timer.days(self:getReminderDelay())
        local remindAfter = self.latestBackup + delay
        local predicate = function () return hs.timer.secondsSinceEpoch() > remindAfter end
        local action = function () return self:checkBackupAge() end
        if predicate() then
            self.menuBarItem:setIcon(self.redIcon, false)
            self.stale = true
        else
            self.reminder = hs.timer.waitUntil(predicate, action, 60)
            self.menuBarItem:setIcon(self.blackIcon)
        end
    end
end

function obj:warn(msg, ...)
    if msg and #msg > 0 then
        local fullMsg = string.format(msg, ...)
        self.log.w(fullMsg)
        hs.alert.show(fullMsg, 3)
    end
end

return obj
