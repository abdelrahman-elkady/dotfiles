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

### Dotfiles

- [ ] Run `./install.sh` (after the Brewfile — it needs uv and brew)
- [ ] Run `./system/macos-defaults.sh` (log out/in afterwards for keyboard settings)

### Apps not covered by Homebrew

- [ ] Wacom tablet driver (download from Wacom)

### Sign-ins & app state

- [ ] VS Code / Cursor — sign in, Settings Sync pulls settings/keybindings/extensions
- [ ] Raycast — import the exported settings
