#!/bin/bash

# --- Start of user-configurable settings (default values, but user will be prompted) ---
# Default backup interval in hours (e.g., 7 for every 7 hours)
DEFAULT_BACKUP_INTERVAL_HOURS=7

# Telegram Bot Token and Chat ID are intentionally left empty here,
# as the script will always prompt the user for them during configuration.
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
# --- End of user-configurable settings ---

SCRIPT_DIR="/usr/local/bin" # Or any preferred location for the script
SCRIPT_NAME="custom_backup.sh"
SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_NAME"
CONFIG_FILE="$HOME/.backup_config"
LOG_FILE="$HOME/.backup_log"

# --- Utility Functions ---

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_dependencies() {
    log_message "Checking for required dependencies: zip and curl..."
    local missing_deps=0
    for dep in "zip" "curl"; do
        if ! command -v "$dep" &> /dev/null; then
            log_message "Dependency '$dep' not found."
            missing_deps=1
        fi
    done

    if [ "$missing_deps" -eq 1 ]; then
        log_message "Attempting to install missing dependencies..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y zip curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y zip curl
        else
            log_message "Error: Cannot automatically install dependencies. Please install 'zip' and 'curl' manually."
            exit 1
        fi
        for dep in "zip" "curl"; do
            if ! command -v "$dep" &> /dev/null; then
                log_message "Error: Failed to install '$dep'. Please install it manually."
                exit 1
            fi
        done
        log_message "Dependencies installed successfully."
    else
        log_message "All dependencies (zip, curl) are already installed."
    fi
}

send_telegram_message() {
    local message="$1"
    local file_path="$2"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        log_message "Error: Telegram BOT_TOKEN or CHAT_ID is not set. Cannot send message."
        return 1
    fi

    if [ -n "$file_path" ] && [ -f "$file_path" ]; then
        log_message "Sending file '$file_path' to Telegram chat ID '$TELEGRAM_CHAT_ID'..."
        RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
          -F chat_id="${TELEGRAM_CHAT_ID}" \
          -F document=@"$file_path" \
          -F caption="$message")
    else
        log_message "Sending message to Telegram chat ID '$TELEGRAM_CHAT_ID'..."
        RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
          -d chat_id="${TELEGRAM_CHAT_ID}" \
          -d text="$message")
    fi

    if echo "$RESPONSE" | grep -q '"ok":true'; then
        log_message "Telegram message sent successfully."
    else
        log_message "Error sending Telegram message: $RESPONSE"
        return 1
    fi
}

# load_config is only for when the script is run by cron for actual backups,
# not for initial setup where we force user input.
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        log_message "Loading configuration from $CONFIG_FILE for backup process..."
        . "$CONFIG_FILE"
        : "${BACKUP_PATHS:=}"
        : "${BACKUP_INTERVAL_HOURS:=0}"
        : "${TELEGRAM_BOT_TOKEN:=}"
        : "${TELEGRAM_CHAT_ID:=}"
        log_message "Configuration loaded for backup."
    else
        log_message "No existing configuration found. Backup cannot proceed without configuration."
        return 1 # Indicate that config loading failed
    fi
}

save_config() {
    log_message "Saving configuration to $CONFIG_FILE..."
    {
        echo "BACKUP_PATHS=($(printf "%q " "${BACKUP_PATHS[@]}"))"
        echo "BACKUP_INTERVAL_HOURS=$BACKUP_INTERVAL_HOURS"
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\""
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\""
    } > "$CONFIG_FILE"
    log_message "Configuration saved."
}

configure_script() {
    log_message "Starting script configuration (all settings will be prompted)..."

    # Always prompt for Telegram Bot Token
    read -rp "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    while [ -z "$TELEGRAM_BOT_TOKEN" ]; do
        log_message "Telegram Bot Token cannot be empty. Please enter a valid token."
        read -rp "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    done

    # Always prompt for Telegram Chat ID
    read -rp "Enter your Telegram Chat ID: " TELEGRAM_CHAT_ID
    while [ -z "$TELEGRAM_CHAT_ID" ]; do
        log_message "Telegram Chat ID cannot be empty. Please enter a valid ID."
        read -rp "Enter your Telegram Chat ID: " TELEGRAM_CHAT_ID
    done

    # Always prompt for backup paths
    BACKUP_PATHS=() # Clear any existing paths for fresh input
    log_message "Enter paths to backup (one per line). Type 'done' to finish:"
    while IFS= read -rp "> " path_input; do
        if [[ "$path_input" == "done" ]]; then
            break
        elif [ -d "$path_input" ] || [ -f "$path_input" ]; then
            BACKUP_PATHS+=("$path_input")
        else
            log_message "Warning: Path '$path_input' does not exist or is not a file/directory. Skipping."
        fi
    done
    if [ ${#BACKUP_PATHS[@]} -eq 0 ]; then
        log_message "Error: No valid backup paths entered. Script cannot proceed without paths."
        exit 1
    fi

    # Prompt for backup interval
    read -rp "Enter backup interval (in hours, e.g., 7 for every 7 hours. Default: $DEFAULT_BACKUP_INTERVAL_HOURS): " input_interval
    if [[ -n "$input_interval" && "$input_interval" =~ ^[0-9]+$ && "$input_interval" -gt 0 ]]; then
        BACKUP_INTERVAL_HOURS="$input_interval"
    else
        log_message "Invalid or empty interval. Using default: $DEFAULT_BACKUP_INTERVAL_HOURS hours."
        BACKUP_INTERVAL_HOURS="$DEFAULT_BACKUP_INTERVAL_HOURS"
    fi

    save_config
    log_message "Configuration complete. Backup paths: ${BACKUP_PATHS[*]}, Interval: ${BACKUP_INTERVAL_HOURS} hours."
    send_telegram_message "Custom Backup Script: Initial configuration complete on $(hostname). Backups will be sent to this chat."
}

setup_cron_job() {
    log_message "Setting up cron job..."
    local cron_command="$SCRIPT_PATH --backup"
    local cron_entry="0 */$BACKUP_INTERVAL_HOURS * * * $cron_command >> $LOG_FILE 2>&1"

    # Remove existing cron job for this script to avoid duplicates
    (crontab -l 2>/dev/null | grep -v "$SCRIPT_NAME") | crontab -

    # Add the new cron job
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    if [ $? -eq 0 ]; then
        log_message "Cron job set successfully to run every $BACKUP_INTERVAL_HOURS hours."
        log_message "Cron job entry: $cron_entry"
    else
        log_message "Error: Failed to set up cron job."
    fi
    send_telegram_message "Custom Backup Script: Cron job configured to run every $BACKUP_INTERVAL_HOURS hours on $(hostname)."
}

perform_backup() {
    log_message "Starting backup process..."
    # Ensure configuration is loaded for actual backup runs
    if ! load_config; then
        log_message "Error: Configuration could not be loaded for backup. Aborting."
        send_telegram_message "Custom Backup Script: Error - Configuration could not be loaded. Please run the script to configure it."
        exit 1
    fi

    if [ ${#BACKUP_PATHS[@]} -eq 0 ]; then
        log_message "Error: No backup paths defined in config file. Please configure the script first."
        send_telegram_message "Custom Backup Script: Error - No backup paths defined in config. Please run the script to configure it."
        exit 1
    fi

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        log_message "Error: Telegram BOT_TOKEN or CHAT_ID is not set in config file. Cannot send backups."
        send_telegram_message "Custom Backup Script: Error - Telegram settings are missing in config. Cannot send backups. Please configure the script."
        exit 1
    fi

    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_filename="backup_${HOSTNAME}_${timestamp}.zip"
    local temp_backup_path="/tmp/$backup_filename"

    log_message "Creating backup archive: $temp_backup_path"

    # Build the zip command dynamically for multiple paths
    local zip_command="zip -r $temp_backup_path"
    for path in "${BACKUP_PATHS[@]}"; do
        if [ -d "$path" ] || [ -f "$path" ]; then
            zip_command="$zip_command \"$path\""
        else
            log_message "Warning: Path '$path' does not exist or is not a file/directory. Skipping."
        fi
    done

    # Execute the zip command
    eval "$zip_command"
    zip_status=$?

    if [ "$zip_status" -eq 0 ]; then
        log_message "Backup archive created successfully."
        send_telegram_message "Backup created successfully on $(hostname). Sending now..." "$temp_backup_path"
        rm -f "$temp_backup_path" # Clean up temporary file
        log_message "Temporary backup file '$temp_backup_path' removed."
    else
        log_message "Error: Failed to create backup archive (zip exit code: $zip_status)."
        send_telegram_message "Custom Backup Script: Error creating backup archive on $(hostname). Zip exit code: $zip_status"
    fi
    log_message "Backup process finished."
}

# --- Main Logic ---

# Check if script is being run for backup or initial setup
if [[ "$1" == "--backup" ]]; then
    perform_backup
    exit 0
fi

# Initial setup and installation
log_message "Starting custom_backup.sh setup..."

# Ensure the script is correctly placed and executable
if [ ! -f "$SCRIPT_PATH" ] || [ ! -x "$SCRIPT_PATH" ] || [[ "$SCRIPT_PATH" -ef "$0" ]]; then
    log_message "Setting up script in $SCRIPT_DIR..."
    sudo mkdir -p "$SCRIPT_DIR"
    sudo cp "$0" "$SCRIPT_PATH"
    sudo chmod +x "$SCRIPT_PATH"
    log_message "Script copied and made executable at $SCRIPT_PATH."
else
    log_message "Script already exists and is executable at $SCRIPT_PATH."
fi

check_dependencies
configure_script # This will now always prompt for all settings and save them
setup_cron_job

log_message "Custom backup script setup complete!"
log_message "To manually trigger a backup: $SCRIPT_PATH --backup"
log_message "To check cron jobs: crontab -l"
