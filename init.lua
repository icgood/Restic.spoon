--- === Restic ===
---
--- Manage [restic](https://restic.github.io/) backups in the menu bar.
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Restic"
obj.version = "0.0"
obj.author = "Ian Good <icgood@gmail.com>"
obj.homepage = "https://github.com/icgood/Restic.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Internal function used to find our location, so we know where to load files from
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)")
end
obj.spoonPath = script_path()

local function getIcon()
    local image = hs.image.imageFromPath(obj.spoonPath .. "/restic.png")
    image:size({ w = 16, h = 16 })
    return image
end

local function getLuaFile(file)
    return dofile(obj.spoonPath .. "/" .. file)
end

local function setSetting(self, name, value)
    self.settings[name] = value
    return self
end

local function getSetting(self, name, default)
    local val = self.settings[name]
    if val then
        return val
    elseif default then
        return default
    else
        error("Must call :set" .. name .. "() first")
    end
end

local function getTimeStr(time)
    if time == 0 then
        return "none"
    else
        return os.date("%b %d, %I:%M %p", latest)
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
    else
        local timeStr = getTimeStr(self.latestBackup)
        table.insert(menu, { title = "Latest Backup: " .. timeStr, disabled = true })
        table.insert(menu, { title = "-" })
        if self.percent then
            table.insert(menu, { title = "Stop Backup", fn = function () self:stopBackup() end })
            table.insert(menu, { title = "Progress: " .. self.percent, disabled = true })
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
    self.menuBarItem = hs.menubar.new(false)
	self.menuBarItem:setIcon(getIcon())
    self.menuBarItem:setMenu(function () return buildMenu(self) end)

    self.settings = {}
    self.log = hs.logger.new(obj.name)

    self.initRepo = getLuaFile("commands/init.lua").new(self, self.log)
    self.snapshots = getLuaFile("commands/snapshots.lua").new(self, self.log)
    self.backup = getLuaFile("commands/backup.lua").new(self, self.log)
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
    self.log.f("starting %s menu bar", obj.name)
    self.menuBarItem:returnToMenuBar()
    self:refreshLatestBackup()
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
    self.log.f("stopping %s menu bar", obj.name)
    self.menuBarItem:removeFromMenuBar()
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
    self.log.df("set restic path to %q", path)
    return setSetting(self, "ResticPath", path)
end

function obj:getResticPath()
    return getSetting(self, "ResticPath", "/usr/local/bin/restic")
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
---  * directories - table array of full directory paths
---
--- Returns:
---  * The Restic object
function obj:setBackupDirs(directories)
    self.log.df("set backup directories to %s", table.concat(directories, ", "))
    return setSetting(self, "BackupDirs", directories)
end

function obj:getBackupDirs()
    local home = hs.fs.pathToAbsolute("~")
    return getSetting(self, "BackupDirs", { home })
end

--- Restic:createRepo()
--- Method
--- Initializes a new restic repository with `restic init`
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function obj:createRepo()
    self.log.f("creating new restic repo in %q", self:getRepository())
    self.latestBackup = nil
    self.initRepo:create()
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
    self.backup:showLog()
end

function obj:refreshLatestBackup()
    self.snapshots:refresh()
end

function obj:updateLatestBackup(latest)
    self.latestBackup = latest
end

function obj:updateProgress(percent)
    self.menuBarItem:setTitle(percent)
    if percent then
        self.percent = percent
    else
        self.percent = nil
        self.snapshots:refresh()
    end
end

function obj:buildResticEnv()
    local env = {
        RESTIC_REPOSITORY = self:getRepository(),
        RESTIC_PASSWORD = self:getPassword(),
    }
    for key, val in pairs(self:getEnvironment()) do
        env[key] = val
    end
    if env.RESTIC_REPOSITORY:sub(1, 3) == "s3:" and not env.AWS_ACCESS_KEY_ID then
        error("Must call :setS3Credentials() first")
    end
    return env
end

function obj:warn(msg, ...)
    if msg and #msg > 0 then
        local fullMsg = string.format(msg, ...)
        self.log.w(fullMsg)
        hs.alert.show(fullMsg, 3)
    end
end

return obj
