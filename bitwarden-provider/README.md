# Bitwarden Vault Provider

Access your Bitwarden/vaultwarden vault directly from the Noctalia launcher. Search logins, copy usernames and passwords, and manage vault items.

## Features

- **Search vault items** - `>bitwarden <query>` or `>bw <query>`
- **Copy username** - `>bitwarden username <item>` or `>bw username <item>`
- **Copy password** - `>bitwarden password <item>` or `>bw password <item>`
- **Browse items** - `>bitwarden items` or `>bw items`
- **View details** - Click any item to open a panel with full details
- **Add/Edit/Delete** items via the panel
- **Type filter** - Use `#<type>` to filter by item type (login, note, card, identity)

## Requirements

- [Bitwarden CLI (`bw`)](https://bitwarden.com/download) must be installed
- Vault must be unlocked (`bw unlock`) or a session token configured in settings

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `>bitwarden` | Open Bitwarden search |
| `>bw` | Shortcut for `>bitwarden` |
| `>bitwarden username <item>` | Search and copy username |
| `>bw username <item>` | Shortcut for username copy |
| `>bitwarden password <item>` | Search and copy password |
| `>bw password <item>` | Shortcut for password copy |
| `>bitwarden items` | Browse all vault items |
| `>bw items` | Shortcut for browsing |
| `>bitwarden new` | Add a new vault item |
| `>bitwarden unlock` | Show unlock instructions |

### Settings

- **Vault URL** - Your Bitwarden/vaultwarden server URL (optional)
- **Session Token** - Paste `BW_SESSION` from `bw unlock` to persist authentication

## Installation

1. Install the `bw` CLI: [bitwarden.com/download](https://bitwarden.com/download)
2. Unlock your vault: `bw unlock`
3. Copy the session token to Settings

## Notes

- Supports both Bitwarden and vaultwarden servers
- Session token avoids repeated re-authentication
- Passwords are never shown in plain text - only copied to clipboard