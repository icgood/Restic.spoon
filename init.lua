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
    local image = hs.image.imageFromPath(obj.spoonPath .. "harddisk.png")
    image:size({ w = 16, h = 16 })
    return image
end

function obj:init()
    self.menuBarItem = hs.menubar.new(false)
	self.menuBarItem:setIcon(getIcon())
    self.menuBarItem:setMenu({ { title = obj.name } })
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

return obj
