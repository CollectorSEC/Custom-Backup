#!/usr/bin/env bash

set -e

CONFIG_FILE="/root/backup_config.json"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
ZIP_FILE="backup_${TIMESTAMP}.zip"
TMP_PATH="/tmp/$ZIP_FILE"
FOLDERS_TO_BACKUP=("/root/marzbot" "/root/arvan-screenshot")

# اولین اجرا: گرفتن اطلاعات و ذخیره در JSON
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
    # خواندن از JSON
    TOKEN=$(grep -oP '(?<="TOKEN": ")[^"]*' "$CONFIG_FILE")
    CHAT_ID=$(grep -oP '(?<="CHAT_ID": ")[^"]*' "$CONFIG_FILE")
fi

# نصب ابزارهای لازم
if ! command -v zip &>/dev/null; then
    echo "Installing zip..."
    apt-get update -y && apt-get install -y zip
fi
if ! command -v curl &>/dev/null; then
    echo "Installing curl..."
    apt-get update -y && apt-get install -y curl
fi

# فشرده‌سازی پوشه‌ها
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

# حذف فایل زیپ
rm -f "$TMP_PATH"

# اضافه کردن کرون جاب (فقط یکبار ایجاد شود)
CRON_CMD="0 */7 * * * curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh | bash"
if ! crontab -l 2>/dev/null | grep -Fq "$CRON_CMD"; then
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
    echo "Cron job set to run every 7 hours."
fi
