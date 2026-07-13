#!/usr/bin/env bash

# macOS defaults
# Run manually on a fresh machine: ./system/macos-defaults.sh
# Some keyboard settings only take effect after logout/restart.

set -e

echo "Applying macOS defaults..."

###############################################################################
# Keyboard & text input                                                       #
###############################################################################

# Fast key repeat (lowest GUI values are 2/15; System Settings can't go lower)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Holding a key repeats it instead of showing the accent character popup
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Disable automatic text meddling
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

###############################################################################
# Trackpad                                                                    #
###############################################################################

# Tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true

# Tap to drag (System Settings → Accessibility → Pointer Control → Trackpad Options)
defaults write com.apple.AppleMultitouchTrackpad Dragging -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging -bool true

# Disable three-finger-tap "Look up & data detectors"
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerTapGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerTapGesture -int 0

# Disable two-finger swipe from right edge (Notification Centre)
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0

###############################################################################
# Finder                                                                      #
###############################################################################

# Show hidden files and all file extensions
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show path bar and status bar
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Icon view by default
defaults write com.apple.finder FXPreferredViewStyle -string "icnv"

# New Finder windows open in home directory
defaults write com.apple.finder NewWindowTarget -string "PfHm"

# Group/sort items by name
defaults write com.apple.finder FXArrangeGroupViewBy -string "Name"

# Show ~/Library
chflags nohidden ~/Library

###############################################################################
# Dock                                                                        #
###############################################################################

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock tilesize -int 49
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock show-recents -bool false

# Minimize windows into their application's icon
defaults write com.apple.dock minimize-to-application -bool true

###############################################################################
# Preview                                                                     #
###############################################################################

# Don't reopen previously viewed files (e.g. PDFs) when opening a new one
defaults write com.apple.Preview ApplePersistenceIgnoreState -bool true

###############################################################################
# Per-app keyboard shortcuts (System Settings → Keyboard → App Shortcuts)    #
###############################################################################
# Symbols: @ = cmd, $ = shift, ~ = option, ^ = ctrl
# NSUserKeyEquivalents lives in each app's macOS defaults domain, NOT in the
# prefs apps export themselves — e.g. the synced iterm2/ plist does NOT carry
# it, which is why the iTerm2 remap is here. Relaunch apps to pick these up.

# All applications
defaults write NSGlobalDomain NSUserKeyEquivalents -dict \
  "Hide Visual Studio Code" '@~^$h' \
  "Minimize" '@~^$m'

# Chrome: DevTools on cmd+shift+i, Email Link on cmd+shift+e
defaults write com.google.Chrome NSUserKeyEquivalents -dict \
  "Developer Tools" '@$i' \
  "Email Link" '@$e'

# iTerm2: remap Close to cmd+d so a stray cmd+w can't kill a tab
defaults write com.googlecode.iterm2 NSUserKeyEquivalents -dict \
  "Close" '@d'

###############################################################################
# Apply                                                                       #
###############################################################################

killall Dock Finder SystemUIServer 2>/dev/null || true

echo "Done."
echo "  - Log out and back in for keyboard/trackpad settings to fully apply."
echo "  - Relaunch Chrome/iTerm2/etc. to pick up the shortcut remaps."
