#!/bin/bash
#
# Proxmox Configuration Backup - Configuration File
#

# Backup destination path (change this to your desired location)
BACKUP_PATH="/path/to/backup/location"

# Backup file prefix (change this to match your node name)
BACKUP_PREFIX="pve-host-config"

# Retention settings
DAILY_RETENTION_DAYS=7
WEEKLY_RETENTION_WEEKS=3
