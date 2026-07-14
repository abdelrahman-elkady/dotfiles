# New machine checklist

Steps for migrating to a new Mac. Automated parts live in `install.sh` and
`system/macos-defaults.sh`; everything else here is manual.

## Before wiping the old machine

- [ ] Snapshot Homebrew packages into the repo (also captures App Store apps if `mas` is installed):

  ```bash
  brew install mas
  brew bundle dump --describe --file=~/dotfiles/Brewfile
  ```

- [ ] Re-export Rectangle prefs if they changed recently (command is in `install.sh`)
- [ ] Raycast → Settings → Advanced → Export (extensions, snippets, hotkeys)

## On the new machine

### Base

- [ ] Install Xcode Command Line Tools: `xcode-select --install`
- [ ] Install [Homebrew](https://brew.sh)
- [ ] Clone this repo: `git clone git@github.com:abdelrahman-elkady/dotfiles.git ~/dotfiles`

### Runtimes & packages

- [ ] Install [nvm](https://github.com/nvm-sh/nvm) + node (needed before the Brewfile — its `npm` entries need npm):

  ```bash
  nvm install 24 && nvm alias default 24
  ```

- [ ] Install everything from the Brewfile — formulae (incl. uv), casks, plus the `uv` tools (powerline, graphifyy, watchdog) and `npm` globals:

  ```bash
  brew bundle install --file=~/dotfiles/Brewfile
  ```

- [ ] `gh auth login`

### ⚠️ Set bash as the default shell — ESSENTIAL

> [!WARNING]
> **🚨 DO NOT SKIP THIS STEP.**
> Everything in this repo — `.bash_profile`, `.bashrc`, aliases, completions,
> the prompt — assumes **bash** is the login shell. New Macs default to zsh,
> so until this is done **none of the dotfiles will load**.

```bash
# brew's bash was installed by the Brewfile step above
echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash
```

Open a new terminal and verify with `echo $SHELL`.

### Dotfiles

- [ ] Run `./install.sh` (after the Brewfile — it needs uv and brew). Run it from **Terminal.app, not iTerm2** — iTerm2 overwrites its own prefs on quit, undoing the theme/settings sync the script configures. If iTerm2 was ever opened before this step, it may also have auto-saved its factory settings **over `iterm2/com.googlecode.iterm2.plist` in the repo** — check with `git status` and `git restore` the plist (while iTerm2 is quit) before launching it again
- [ ] Run `./system/macos-defaults.sh` (log out/in afterwards for keyboard settings)

### System settings that can't be scripted

- [ ] Set the computer name:

  ```bash
  sudo scutil --set ComputerName "NAME_GOES_HERE"
  sudo scutil --set LocalHostName "NAME_GOES_HERE"
  sudo scutil --set HostName "NAME_GOES_HERE"
  ```

- [ ] Swap modifier keys — System Settings → Keyboard → Keyboard Shortcuts… → Modifier Keys → **fn ↔ Control** (the stored mapping is keyed to each keyboard's hardware ID, so it can't be replayed on a new machine; repeat for external keyboards)
- [ ] Safari → Settings → General → uncheck **Open "safe" files after downloading**
- [ ] System Settings → Privacy & Security → Advanced → enable **Require an administrator password to access system-wide settings**
- [ ] Power settings — worth re-deciding per machine; previous machine's values:

  ```bash
  sudo pmset -b displaysleep 5   # battery: display off after 5 min
  sudo pmset -c displaysleep 10  # AC: display off after 10 min
  sudo pmset -c sleep 0          # AC: never system-sleep while display is off
  ```

### Apps not covered by Homebrew

- [ ] Wacom tablet driver (download from Wacom)

### Sign-ins & app state

- [ ] VS Code / Cursor — sign in, Settings Sync pulls settings/keybindings/extensions
- [ ] Raycast — import the exported settings
