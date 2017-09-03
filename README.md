# Restic.spoon
Hammerspoon module to manage restic backups with the menu bar

### Installation
Install the spoon with:

```bash
git clone https://github.com/icgood/Restic.spoon.git ~/.hammerspoon/Spoons/Restic.spoon
```

### Configuration

Update your `~/.hammerspoon/init.lua` with the following:

```lua
hs.loadSpoon("Restic")
spoon.Restic:setRepository("s3:s3.amazonaws.com/bucket_name")
spoon.Restic:setPassword("<restic-repo-password>")
spoon.Restic:setS3Credentials("<aws-access-key>", "<aws-secret-key>")
spoon.Restic:start()
```

Finally, reload your Hammerspoon config to see Restic.spoon in the menu bar.

See _Help_ in the menu bar for documentation on additional settings and console
commands.

#### Save/Load

Once you have a working configuration, save them to `~/restic.spoon` from the
Hammerspoon console:

```lua
spoon.Restic:saveSettings()
```

You can then modify your `~/.hammerspoon/init.lua` script and replace all of
the spoon initialization with:

```lua
hs.loadSpoon("Restic"):start()
```

## FAQ

#### Why can't I see the backup progress?

Backups are run with administrator privileges, to make sure the entire system
can be backed up. As such, only root may send a `SIGUSR1` signal to the restic
process to trigger a progress update. I have an
[issue](https://github.com/restic/restic/issues/1199) open with restic to
provide a way for automatic progress updates for non-TTY backups.
