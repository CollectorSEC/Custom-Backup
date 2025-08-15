#!/usr/bin/env bash

set -e

# گرفتن اطلاعات از کاربر
read -rp "Enter Telegram bot token: " TOKEN
read -rp "Enter Telegram chat ID: " CHAT_ID

SOURCE_DIR="/root"
TIMESTAMP=$(date +'%Y%m%d_%H%M%S')
ZIP_FILE="backup_${TIMESTAMP}.zip"

# نصب ابزارهای لازم
if ! command -v zip &>/dev/null; then
    echo "Installing zip..."
    apt-get update -y && apt-get install -y zip
fi
if ! command -v curl &>/dev/null; then
    echo "Installing curl..."
    apt-get update -y && apt-get install -y curl
fi

# فشرده‌سازی فولدر /root
echo "Zipping folder '$SOURCE_DIR'..."
zip -r "$ZIP_FILE" "$SOURCE_DIR" >/dev/null

# ارسال به تلگرام
echo "Sending backup to Telegram..."
curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendDocument" \
    -F chat_id="$CHAT_ID" \
    -F document=@"$ZIP_FILE" >/dev/null

echo "Backup sent successfully."

# حذف فایل زیپ
rm -f "$ZIP_FILE"

# اضافه کردن کرون جاب
CRON_CMD="0 */7 * * * curl -sL https://raw.githubusercontent.com/CollectorSEC/Custom-Backup/main/custom_backup.sh | bash"
(crontab -l 2>/dev/null | grep -F -v "custom_backup.sh" ; echo "$CRON_CMD") | crontab -

echo "Cron job set to run every 7 hours."
