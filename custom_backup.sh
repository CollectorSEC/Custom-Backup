#!/usr/bin/env bash
set -e

SCRIPT_PATH="/root/custom_backup.sh"
CONFIG_FILE="/root/backup_config.json"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
ZIP_FILE="backup_${TIMESTAMP}.zip"
TMP_PATH="/tmp/$ZIP_FILE"
FOLDERS_TO_BACKUP=("/root/marzbot" "/root/arvan-screenshot")

# اگر فایل اسکریپت محلی وجود نداره، خودش رو ذخیره کنه
if [ "$0" != "$SCRIPT_PATH" ]; then
    echo "Saving script to $SCRIPT_PATH..."
    curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh -o "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    exec "$SCRIPT_PATH"
    exit 0
fi

# اولین اجرا: گرفتن TOKEN و CHAT_ID و ذخیره در JSON
if [ ! -f "$CONFIG_FILE" ]; then
    read -rp "Enter Telegram bot token: " TOKEN
    read -rp "Enter Telegram chat ID: " CHAT_ID

    cat <<EOF > "$CONFIG_FILE"
{
    "TOKEN": "$TOKEN",
    "CHAT_ID": "$CHAT_ID"
}
EOF
    chmod 600 "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
else
    TOKEN=$(grep -oP '(?<="TOKEN": ")[^"]*' "$CONFIG_FILE")
    CHAT_ID=$(grep -oP '(?<="CHAT_ID": ")[^"]*' "$CONFIG_FILE")
fi

# نصب ابزارها
if ! command -v zip &>/dev/null; then
    apt-get update -y && apt-get install -y zip
fi
if ! command -v curl &>/dev/null; then
    apt-get update -y && apt-get install -y curl
fi

# بکاپ گرفتن
echo "Zipping selected folders..."
zip -r "$TMP_PATH" "${FOLDERS_TO_BACKUP[@]}" >/dev/null 2>&1 || {
    echo "Error: Failed to zip folders."
    exit 1
}

# ارسال به تلگرام
echo "Sending backup to Telegram..."
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
    -F chat_id="$CHAT_ID" \
    -F document=@"$TMP_PATH" >/dev/null

echo "Backup sent successfully."
rm -f "$TMP_PATH"

# اضافه کردن کرون جاب به نسخه محلی
CRON_CMD="0 */7 * * * /bin/bash $SCRIPT_PATH"
if ! crontab -l 2>/dev/null | grep -Fq "$CRON_CMD"; then
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "Cron job set to run every 7 hours from local script."
fi
