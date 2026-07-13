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
# Apply                                                                       #
###############################################################################

killall Dock Finder SystemUIServer 2>/dev/null || true

echo "Done. Log out and back in for keyboard settings to fully apply."
