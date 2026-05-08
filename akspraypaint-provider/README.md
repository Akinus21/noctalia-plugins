# AKSprayPaint

Theme-aware wallpaper recoloring for Noctalia Shell.

Reads the active Noctalia theme from `~/.config/noctalia/colors.json`, extracts the color palette using `matugen`, and applies a full Oklch-based color transfer to the wallpaper image. The recolored wallpaper is cached and reused on subsequent runs.

## Features

- **Theme-aware recoloring**: Automatically matches your wallpaper to the active Noctalia theme colors
- **Watch daemon**: Runs in the background and auto-recolors wallpaper whenever the theme changes
- **Manual recolor**: Use the Settings panel to pick a wallpaper and apply theme colors on demand
- **Caching**: Recolored wallpapers are cached by theme hash for fast reuse

## Requirements

- [AKSprayPaint](https://github.com/Akinus21/akspraypaint) installed via Homebrew:
  ```
  brew install akspraypaint
  ```
- [matugen](https://github.com/Akinus21/matugen) for color extraction (installed as a dependency by Homebrew)

## Usage

### Settings

1. Open **Settings → AKSprayPaint**
2. Set the **AKSprayPaint Path** if not using the default (`akspraypaint`)
3. Check that the installation is detected
4. Toggle **Enable Daemon** to ON to start the watch daemon
5. Choose a wallpaper with **Browse** and click **Set** to apply theme colors

### Daemon

When enabled, the daemon (`akspraypaint watch`) runs in the background and watches `~/.config/noctalia/colors.json` for changes. When the theme changes, it automatically recolors and updates the wallpaper.

## Technical Details

- **Cache**: `~/.cache/akspraypaint/<theme_hash>/`
- **PID file**: `~/.cache/akspraypaint/watch.pid`
- **Theme config**: `~/.config/noctalia/colors.json`
- **Wallpaper setters**: `swww`, `hyprpaper`, `swaybg`, `feh` (auto-detected)