# Custom Backup Script

This is a Bash script that automates backups of specified directories or files, zips them, and sends them to a Telegram bot. It uses a cron job to schedule backups at user-defined intervals (default: every 7 hours).

## Features
- Automatically checks and installs prerequisites (`zip` and `curl`).
- Prompts for paths to back up during setup.
- Configurable backup interval (in hours).
- Zips backup files and sends them to a Telegram chat via a bot.
- Configures a cron job for automated backups.

## Prerequisites
- A Linux server (Debian/Ubuntu or RedHat/CentOS supported for auto-installing dependencies).
- A Telegram bot token and chat ID (obtain from [BotFather](https://t.me/BotFather)).
- `sudo` access for installing dependencies (if not already installed).

## Installation
1. Clone or download the script from this repository:
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

Or use the one-liner for automatic setup:
```bash
curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh -o custom_backup.sh && chmod +x custom_backup.sh && ./custom_backup.sh
```

## Setup
When you run the script for the first time:
1. It checks for `zip` and `curl`. If not installed, it attempts to install them (supports Debian/Ubuntu or RedHat/CentOS).
2. Prompts you to enter paths to back up (one per line, type `done` when finished).
3. Asks for the backup interval (in hours, default is 7).
4. Requests your Telegram bot token and chat ID.
5. Saves the configuration to `~/.backup_config`.
6. Sets up a cron job to run backups automatically.

## Usage
- **Manual Setup**: Run `./custom_backup.sh` to configure or reconfigure the script.
- **Backup Execution**: The cron job runs `./custom_backup.sh --backup` automatically at the specified interval.
- **Check Cron Job**: Verify the cron job with:
  ```bash
  crontab -l
  ```

## Notes
- Ensure your server has internet access to send files to Telegram.
- Backups are temporarily stored in `/tmp` and deleted after being sent.
- If a path doesn't exist during backup, it will be skipped with a warning.
- For manual backups, run `./custom_backup.sh --backup`.

## Troubleshooting
- **Dependencies not installed**: Ensure you have `sudo` access or manually install `zip` and `curl`.
- **Telegram issues**: Verify your bot token and chat ID are correct.
- **Cron not running**: Check the cron service is active (`systemctl status cron`) and the cron job is listed (`crontab -l`).

## License
This project is licensed under the MIT License.
