#!/bin/bash

# Custom Backup Script for Server
# This script handles its own installation (download, chmod +x, execution), checks prerequisites,
# sets up paths to backup, schedules cron jobs, and sends zipped backups to Telegram bot.
# All configurations are defined within this script, and all steps are fully automated.

# Usage:
# Auto-install: curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh | bash
# Backup run: ./custom_backup.sh --backup (triggered by cron)

# Default configurations (edit these before uploading to GitHub)
PATHS=(
    "/path/to/backup1"
    "/path/to/backup2"
)
INTERVAL=7
TOKEN="your_bot_token_here"
CHAT_ID="your_chat_id_here"

CONFIG_FILE="$HOME/.backup_config"
REPO_URL="https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh"

# Function to handle self-installation (downloads script, sets execute permission, and runs it)
self_install() {
    echo "Checking if script needs to be downloaded..."
    SCRIPT_NAME=$(basename "$0")
    # Check if script exists and is executable
    if [[ ! -f "$SCRIPT_NAME" || ! -x "$SCRIPT_NAME" ]]; then
        echo "Downloading $SCRIPT_NAME from GitHub..."
        curl -sL "$REPO_URL" -o "$SCRIPT_NAME"
        if [[ $? -ne 0 ]]; then
            echo "Failed to download $SCRIPT_NAME"
            exit 1
        fi
        # Set execute permission
        chmod +x "$SCRIPT_NAME"
        if [[ $? -ne 0 ]]; then
            echo "Failed to set execute permission"
            exit 1
        fi
        echo "Script downloaded and made executable."
        # Re-run the script after download
        exec ./"$SCRIPT_NAME"
    fi
}

# Function to check and install prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    for cmd in zip curl; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "$cmd is not installed. Attempting to install..."
            if [[ -f /etc/debian_version ]]; then
                sudo apt update && sudo apt install -y "$cmd"
            elif [[ -f /etc/redhat-release ]]; then
                sudo yum install -y "$cmd"
            else
                echo "Unsupported OS. Please install $cmd manually."
                exit 1
            fi
        fi
    done
    echo "All prerequisites are installed."
}

# Function to setup the script
setup() {
    check_prerequisites
    echo "Welcome to Custom Backup Script Setup."

    # Check if config file exists (from previous setup)
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Existing configuration found, using it."
        source "$CONFIG_FILE"
    else
        # Use default configurations or prompt for custom ones
        echo "Use default settings? (y/n)"
        read -r use_default
        if [[ "$use_default" != "y" && "$use_default" != "Y" ]]; then
            # Ask for paths
            paths=()
            echo "Enter path to backup (or 'done' to finish):"
            while true; do
                read -r path
                if [[ "$path" == "done" ]]; then
                    break
                fi
                if [[ -n "$path" ]]; then
                    paths+=("$path")
                    echo "Enter next path to backup (or 'done' to finish):"
                fi
            done
            if [[ ${#paths[@]} -gt 0 ]]; then
                PATHS=("${paths[@]}")
            fi

            # Ask for backup interval
            echo "Enter backup interval in hours (default: 7):"
            read -r interval
            if [[ -n "$interval" && "$interval" =~ ^[0-9]+$ ]]; then
                INTERVAL="$interval"
            fi

            # Ask for Telegram bot details
            echo "Enter your Telegram Bot Token:"
            read -r TELEGRAM_TOKEN
            echo "Enter your Telegram Chat ID:"
            read -r TELEGRAM_CHAT_ID
            if [[ -n "$TELEGRAM_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
                TOKEN="$TELEGRAM_TOKEN"
                CHAT_ID="$TELEGRAM_CHAT_ID"
            fi
        fi

        # Save config
        echo "PATHS=(${PATHS[@]@Q})" > "$CONFIG_FILE"
        echo "INTERVAL=$INTERVAL" >> "$CONFIG_FILE"
        echo "TOKEN=$TOKEN" >> "$CONFIG_FILE"
        echo "CHAT_ID=$CHAT_ID" >> "$CONFIG_FILE"
    fi

    # Validate configurations
    if [[ -z "${PATHS[*]}" || -z "$INTERVAL" || -z "$TOKEN" || -z "$CHAT_ID" ]]; then
        echo "Invalid or incomplete configuration. Please check settings."
        exit 1
    fi

    # Setup cron job
    SCRIPT_PATH=$(realpath "$0")
    CRON_JOB="0 */$INTERVAL * * * $SCRIPT_PATH --backup"
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job set: Every $INTERVAL hours."
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
    self_install
    setup
fi
