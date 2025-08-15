#!/bin/bash

# Custom Backup Script for Server
# This script sets up paths to backup, schedules cron jobs, and sends zipped backups to Telegram bot.

# Usage:
# First run: ./custom_backup.sh (for setup)
# Backup run: ./custom_backup.sh --backup (triggered by cron)

CONFIG_FILE="$HOME/.backup_config"
TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
BACKUP_INTERVAL=7  # Default 7 hours

# Function to setup the script
setup() {
    echo "Welcome to Custom Backup Script Setup."

    # Ask for paths
    paths=()
    echo "Enter paths to backup (one per line). Type 'done' when finished:"
    while true; do
        read -r path
        if [[ "$path" == "done" ]]; then
            break
        fi
        paths+=("$path")
    done

    # Ask for backup interval
    echo "Enter backup interval in hours (default: 7):"
    read -r interval
    if [[ -n "$interval" && "$interval" =~ ^[0-9]+$ ]]; then
        BACKUP_INTERVAL="$interval"
    fi

    # Ask for Telegram bot details
    echo "Enter your Telegram Bot Token:"
    read -r TELEGRAM_TOKEN
    echo "Enter your Telegram Chat ID:"
    read -r TELEGRAM_CHAT_ID

    # Save config
    echo "PATHS=(${paths[@]@Q})" > "$CONFIG_FILE"
    echo "INTERVAL=$BACKUP_INTERVAL" >> "$CONFIG_FILE"
    echo "TOKEN=$TELEGRAM_TOKEN" >> "$CONFIG_FILE"
    echo "CHAT_ID=$TELEGRAM_CHAT_ID" >> "$CONFIG_FILE"

    # Setup cron job
    SCRIPT_PATH=$(realpath "$0")
    CRON_JOB="0 */$BACKUP_INTERVAL * * * $SCRIPT_PATH --backup"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job set: Every $BACKUP_INTERVAL hours."
    echo "Setup complete. Backups will start automatically."
}

# Function to perform backup
backup() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Config file not found. Run setup first."
        exit 1
    fi

    source "$CONFIG_FILE"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    for path in "${PATHS[@]}"; do
        if [[ -e "$path" ]]; then
            ZIP_FILE="/tmp/backup_${TIMESTAMP}_$(basename "$path").zip"
            zip -r "$ZIP_FILE" "$path" >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                curl -F document=@"$ZIP_FILE" "https://api.telegram.org/bot$TOKEN/sendDocument?chat_id=$CHAT_ID" >/dev/null 2>&1
                rm "$ZIP_FILE"
                echo "Backup of $path sent to Telegram."
            else
                echo "Failed to zip $path."
            fi
        else
            echo "Path $path does not exist."
        fi
    done
}

# Main logic
if [[ "$1" == "--backup" ]]; then
    backup
else
    setup
fi
