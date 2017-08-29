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
    local image = hs.image.imageFromPath(obj.spoonPath .. "/harddisk.png")
    image:size({ w = 16, h = 16 })
    return image
end

local function getLuaFile(file)
    return dofile(obj.spoonPath .. "/" .. file)
end

function obj:init()
    self.menuBarItem = hs.menubar.new(false)
	self.menuBarItem:setIcon(getIcon())

    self.status = getLuaFile("status.lua").new(self)
    self.backup = getLuaFile("backup.lua").new(self)

    self:updateMenu()
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
    self.menuBarItem:returnToMenuBar()
    self.status:refresh()
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
    self.menuBarItem:removeFromMenuBar()
end

function obj:getResticPath()
    return hs.settings.get(obj.name .. ".Path")
end

function obj:getResticEnv()
    return hs.settings.get(obj.name .. ".Environment")
end

function obj:getBackupDir()
    return hs.settings.get(obj.name .. ".BackupDir")
end

function obj:setLatestBackup(latest)
    local latestBackup = os.date("%F %T", latest)
    self.latestBackup = latestBackup
    self:updateMenu()
end

function obj:setProgress(progress)
    if progress then
        self.progress = progress
    else
        self.progress = nil
        self.status:refresh()
    end
    self:updateMenu()
end

function obj:updateMenu()
    local menu = {
        { title = "Latest Backup: " .. (self.latestBackup or "unknown") },
        { title = "-" },
    }
    if self.progress then
        table.insert(menu, { title = "Stop Backup", fn = function () self.backup:stop() end })
        table.insert(menu, { title = "Progress: " .. self.progress, disabled = true })
    else
        table.insert(menu, { title = "Backup Now", fn = function () self.backup:start() end })
    end
    self.menuBarItem:setMenu(menu)
end

return obj
