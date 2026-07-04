# Flatpak Manager

Full Flatpak management plugin for Noctalia with search, install, uninstall, update, run, and kill capabilities.

## Features

- **Search & Install**: Search available flatpaks from configured remotes and install them
- **Manage Installed**: View, run, update, and uninstall your installed flatpaks
- **Multiple Remotes**: Support for Flathub, Flathub Beta, GNOME Nightly, GNOME Stable, KDE, and more
- **User/System Scope**: Choose whether to manage user-installed or system-wide flatpaks
- **Running Apps**: View and stop running flatpak applications
- **Updates**: Check for and apply updates to your installed flatpaks

## Commands

Access via launcher with `>fp` or `>flatpak`:

- `>fp` - Open Flatpak Manager
- `>fp list` - List installed flatpaks
- `>fp install <name>` - Install a flatpak
- `>fp update <name>` - Update a flatpak
- `>fp run <name>` - Run a flatpak
- `>fp kill <name>` - Stop a running flatpak

## Settings

- **Default Scope**: User (default) or System
- **Enabled Remotes**: Choose which flatpak repositories to use

## Requirements

- `flatpak` command line tool must be installed
- For user scope: No special permissions needed
- For system scope: Root privileges required

## Supported Remotes

- Flathub (default)
- Flathub Beta
- GNOME Nightly
- GNOME Stable
- KDE
- KDE Next

## Usage

1. Open the launcher with your configured hotkey
2. Type `>fp` to access Flatpak Manager
3. Browse installed flatpaks, search for new ones, or check for updates
4. Use the panel to manage remotes and default scope settings
