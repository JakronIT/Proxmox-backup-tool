#!/bin/bash
#
# Proxmox PVE Host Configuration Backup Script
# Creates backup of essential Proxmox configuration files
# Retention: 7 daily backups + one backup from each of the previous 3 weeks
#

set -e

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
HOSTNAME=$(hostname)
DATE_NOW=$(date +%Y-%m-%d_%H-%M-%S)
DATE_TODAY=$(date +%Y-%m-%d)

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_PATH"

# Essential files and directories to backup
# Based on Proxmox community best practices
PVE_BACKUP_SET="
/etc/pve/
/etc/network/interfaces
/etc/passwd
/etc/group
/etc/shadow
/etc/gshadow
/etc/hosts
/etc/hostname
/etc/resolv.conf
/etc/lvm/
/etc/vzdump.conf
/etc/sysctl.conf
/etc/ksmtuned.conf
/etc/modprobe.d/
/etc/cron.d/
/etc/cron.daily/
/etc/cron.hourly/
/etc/cron.monthly/
/etc/cron.weekly/
/etc/crontab
/etc/aliases
/etc/fstab
/etc/ssh/
/etc/ssl/
/etc/systemd/system/
/var/lib/pve-cluster/
"

# Optional files (if they exist)
PVE_OPTIONAL_SET="
/etc/apcupsd/
/etc/multipath/
/etc/multipath.conf
/etc/iscsi/
/etc/corosync/
"

# Backup filename
BACKUP_FILE="$BACKUP_PATH/${BACKUP_PREFIX}_${HOSTNAME}_${DATE_NOW}.tar.gz"

echo "$(date): Starting Proxmox configuration backup..."
echo "Location: $BACKUP_FILE"

# Check if destination directory exists and is accessible
if [ ! -d "$BACKUP_PATH" ]; then
    echo "ERROR: Directory $BACKUP_PATH does not exist or is not accessible"
    exit 1
fi

if [ ! -w "$BACKUP_PATH" ]; then
    echo "ERROR: No write permissions for $BACKUP_PATH"
    exit 1
fi

# Create list of files to backup (check if they exist)
BACKUP_LIST=""
for item in $PVE_BACKUP_SET; do
    if [ -e "$item" ]; then
        BACKUP_LIST="$BACKUP_LIST $item"
    else
        echo "WARNING: $item does not exist, skipping"
    fi
done

# Add optional files if they exist
for item in $PVE_OPTIONAL_SET; do
    if [ -e "$item" ]; then
        BACKUP_LIST="$BACKUP_LIST $item"
        echo "Added optional file: $item"
    fi
done

# Create backup using tar with gzip compression
if tar -czf "$BACKUP_FILE" --absolute-names $BACKUP_LIST 2>/dev/null; then
    echo "$(date): Backup created successfully: $BACKUP_FILE"

    # Check file size
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "Backup size: $BACKUP_SIZE"
else
    echo "ERROR: Failed to create backup"
    exit 1
fi

# FILE RETENTION MANAGEMENT
echo "$(date): Starting cleanup of old backups..."

# Find all backup files with this prefix
cd "$BACKUP_PATH"

# 1. Keep all files from the last 7 days
SEVEN_DAYS_AGO=$(date -d "$DAILY_RETENTION_DAYS days ago" +%Y-%m-%d)
echo "Keeping all backups from the last $DAILY_RETENTION_DAYS days (since $SEVEN_DAYS_AGO)"

# 2. For older files, keep one from each week for the previous weeks
for week in $(seq 1 $WEEKLY_RETENTION_WEEKS); do
    # Calculate week start date (Monday)
    WEEK_START=$(date -d "$((week * 7)) days ago monday" +%Y-%m-%d)
    WEEK_END=$(date -d "$((week * 7 - 6)) days ago sunday" +%Y-%m-%d)

    echo "Checking week $week: from $WEEK_END to $WEEK_START"

    # Find newest backup from this week
    WEEKLY_BACKUP=$(find . -name "${BACKUP_PREFIX}_${HOSTNAME}_*" -type f | \
        grep -E "${BACKUP_PREFIX}_${HOSTNAME}_[0-9]{4}-[0-9]{2}-[0-9]{2}" | \
        awk -v start="$WEEK_END" -v end="$WEEK_START" '
        {
            # Extract date from filename
            match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)
            date = substr($0, RSTART, RLENGTH)
            if (date >= start && date <= end) {
                print date " " $0
            }
        }' | sort -r | head -1 | cut -d' ' -f2-)

    if [ -n "$WEEKLY_BACKUP" ]; then
        echo "Keeping weekly backup: $WEEKLY_BACKUP"
        # Mark this file to keep (create list)
        echo "$WEEKLY_BACKUP" >> /tmp/keep_files.tmp
    fi
done

# 3. Delete all remaining files older than specified days
echo "Removing old backup files..."

# Find all backup files older than retention period
find . -name "${BACKUP_PREFIX}_${HOSTNAME}_*" -type f -mtime +$DAILY_RETENTION_DAYS | while read file; do
    # Check if file is on the keep list
    if [ -f /tmp/keep_files.tmp ] && grep -q "$file" /tmp/keep_files.tmp; then
        echo "Keeping: $file (weekly backup)"
    else
        echo "Removing old backup: $file"
        rm -f "$file"
    fi
done

# Clean up temporary file
rm -f /tmp/keep_files.tmp

echo "$(date): Backup and cleanup completed successfully"

# Show statistics
echo "Current backup files:"
ls -lah "${BACKUP_PREFIX}_${HOSTNAME}_"* 2>/dev/null | tail -10 || echo "No backup files found"
