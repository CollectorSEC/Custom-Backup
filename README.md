# Custom Backup Script

This is a Bash script that automates backups of specified directories or files, zips them, and sends them to a Telegram bot. It uses a cron job to schedule backups at user-defined intervals (default: every 7 hours). The script is self-contained, handling its own installation and configuration without external files.

## Features
- Automatically downloads itself from GitHub if not present.
- Checks and installs prerequisites (`zip` and `curl`).
- Uses default configurations defined within the script or prompts for custom ones.
- Configurable backup interval (in hours).
- Zips backup files and sends them to a Telegram chat via a bot.
- Configures a cron job for automated backups.

## Prerequisites
- A Linux server (Debian/Ubuntu or RedHat/CentOS supported for auto-installing dependencies).
- A Telegram bot token and chat ID (obtain from [BotFather](https://t.me/BotFather)).
- `sudo` access for installing dependencies (if not already installed).
- Internet access for downloading the script and sending backups to Telegram.

## Installation
### Fully Automated Installation
1. Edit the default configurations directly in `custom_backup.sh` before uploading to GitHub:
   - `PATHS`: Array of paths to back up (e.g., `/home/user/data`).
   - `INTERVAL`: Backup interval in hours (e.g., 7).
   - `TOKEN`: Telegram bot token.
   - `CHAT_ID`: Telegram chat ID.
2. Run the script directly from GitHub:
   ```bash
   curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh | bash
   ```
   This downloads `custom_backup.sh`, sets execute permissions, installs prerequisites, and runs setup using the default settings.

### Manual Installation
1. Download the script:
   ```bash
   curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh -o custom_backup.sh
   ```
2. Make the script executable:
   ```bash
   chmod +x custom_backup.sh
   ```
3. Run the script to start setup:
   ```bash
   ./custom_backup.sh
   ```

## Setup
### Automated Setup
- If the default configurations in `custom_backup.sh` are set (valid `PATHS`, `INTERVAL`, `TOKEN`, and `CHAT_ID`), the script uses them and configures the cron job automatically.
- The configuration is saved to `~/.backup_config` for subsequent runs.

### Manual Setup
When you run `./custom_backup.sh`:
1. It checks for `zip` and `curl`. If not installed, it attempts to install them (supports Debian/Ubuntu or RedHat/CentOS).
2. Asks if you want to use default settings (defined in the script).
3. If you choose not to use defaults:
   - Prompts for paths to back up (one per line, type `done` when finished).
   - Asks for the backup interval (in hours, default is 7).
   - Requests your Telegram bot token and chat ID.
4. Saves the configuration to `~/.backup_config`.
5. Sets up a cron job to run backups automatically.

## Usage
- **Manual Setup**: Run `./custom_backup.sh` to configure or reconfigure the script.
- **Backup Execution**: The cron job runs `./custom_backup.sh --backup` automatically at the specified interval.
- **Check Cron Job**: Verify the cron job with:
  ```bash
  crontab -l
  ```

## Notes
- The script downloads itself from `https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh` if not present or not executable.
- Backups are temporarily stored in `/tmp` and deleted after being sent.
- If a path doesn't exist during backup, it will be skipped with a warning.
- For manual backups, run `./custom_backup.sh --backup`.

## Troubleshooting
- **Dependencies not installed**: Ensure you have `sudo` access or manually install `zip` and `curl`.
- **Telegram issues**: Verify your bot token and chat ID are correct.
- **Cron not running**: Check the cron service is active (`systemctl status cron`) and the cron job is listed (`crontab -l`).
- **Invalid configuration**: Ensure all settings in `custom_backup.sh` are correctly filled or provide valid inputs during manual setup.
- **Download issues**: Ensure internet access and correct repository URL.

## License
This project is licensed under the MIT License.
