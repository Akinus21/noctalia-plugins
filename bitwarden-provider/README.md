# Bitwarden Vault

Access your Bitwarden vault from the Noctalia launcher using the `bw` CLI.

## Commands

- `>bitwarden` or `>bw` - Search vault items
- `>bitwarden items` - Browse all items
- `>bitwarden username <name>` - Copy username
- `>bitwarden password <name>` - Copy password

## Requirements

- [Bitwarden CLI](https://bitwarden.com/download) installed
- Vault unlocked (`bw unlock`) or session token configured in settings

## Settings

- **Vault URL**: Your Bitwarden/vaultwarden server URL
- **Session Token**: Output of `bw unlock` to persist login

## Usage

1. Install `bw` CLI: `npm install -g @bitwarden/cli` or download from bitwarden.com
2. Unlock your vault: `bw unlock`
3. Enter `>bw` in the launcher to search items