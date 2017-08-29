# Restic.spoon
Hammerspoon module to manage restic backups with the menu bar

### Installation
Install the spoon with:

```bash
git clone https://github.com/icgood/Restic.spoon.git ~/.hammerspoon/Spoons/Restic.spoon
```

Update your `~/.hammerspoon/init.lua` with the following:

```lua
hs.loadSpoon("Restic")
spoon.Restic:setRepository("s3:s3.amazonaws.com/bucket_name")
spoon.Restic:setPassword("<restic-repo-password>")
spoon.Restic:setS3Credentials("<aws-access-key>", "<aws-secret-key>")
spoon.Restic:start()
```

Finally, reload your Hammerspoon config to see Restic.spoon in the menubar.
