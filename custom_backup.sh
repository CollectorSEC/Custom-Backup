#!/usr/bin/env bash

set -e

# گرفتن اطلاعات از کاربر
read -rp "Enter Telegram bot token: " TOKEN
read -rp "Enter Telegram chat ID: " CHAT_ID

TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
ZIP_FILE="backup_${TIMESTAMP}.zip"
TMP_PATH="/tmp/$ZIP_FILE"

# بررسی وجود پوشه‌ها
for DIR in "/root/marzbot" "/root/arvan-screenshot"; do
    if [ ! -d "$DIR" ]; then
        echo "Warning: Folder $DIR not found, skipping..."
    fi
done

# نصب ابزارهای لازم
if ! command -v zip &>/dev/null; then
    echo "Installing zip..."
    apt-get update -y && apt-get install -y zip
fi
if ! command -v curl &>/dev/null; then
    echo "Installing curl..."
    apt-get update -y && apt-get install -y curl
fi

# فشرده‌سازی فقط دو پوشه مورد نظر
echo "Zipping selected folders..."
zip -r "$TMP_PATH" /root/marzbot /root/arvan-screenshot >/dev/null 2>&1 || {
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

# اضافه کردن کرون جاب
CRON_CMD="0 */7 * * * curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh | bash"
(crontab -l 2>/dev/null | grep -F -v "custom_backup.sh" ; echo "$CRON_CMD") | crontab -

echo "Cron job set to run every 7 hours."
