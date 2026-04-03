# Proxmox Configuration Backup Tool

A simple bash script to backup essential Proxmox VE configuration files. This tool helps protect your Proxmox setup by creating regular backups of critical configuration files, making disaster recovery and system restoration much easier.

## What it does

- Backs up essential Proxmox configuration files and directories
- Maintains intelligent retention: 7 daily backups + weekly backups for 3 weeks
- Creates compressed tar.gz archives with timestamps
- Automatically cleans up old backups
- Sends webhook notifications on backup success or failure

## Files backed up

The script backs up these critical configuration files:
- `/etc/pve/` - Proxmox cluster configuration
- `/etc/network/interfaces` - Network configuration
- `/etc/passwd`, `/etc/group`, `/etc/shadow` - User accounts
- `/etc/hosts`, `/etc/hostname`, `/etc/resolv.conf` - System identity
- `/etc/lvm/` - LVM configuration
- `/etc/ssh/` - SSH configuration
- `/etc/ssl/` - SSL certificates
- And many more essential system files

## Quick Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/JakronIT/Proxmox-backup-tool.git
   cd proxmox-node-backup
   ```

2. **Edit the configuration:**
   ```bash
   nano config.sh
   ```
   Change `BACKUP_PATH` to your desired backup location and `BACKUP_PREFIX` to name your backup files.

3. **Make the script executable:**
   ```bash
   chmod +x pve-backup-config.sh
   ```

4. **Test the script:**
   ```bash
   ./pve-backup-config.sh
   ```

## Automated Backups with Cron

To run daily backups automatically, add to crontab:

1. **Edit crontab:**
   ```bash
   crontab -e
   ```

2. **Add this line for daily backup at 4 AM with logging:**
   ```bash
   0 4 * * * /path/to/proxmox-node-backup/pve-backup-config.sh >> /var/log/pve-backup.log 2>&1
   ```


## Configuration

Edit `config.sh` to customize:
- `BACKUP_PATH` - Where to store backups
- `BACKUP_PREFIX` - Prefix for backup files
- `DAILY_RETENTION_DAYS` - How many daily backups to keep (default: 7)
- `WEEKLY_RETENTION_WEEKS` - How many weekly backups to keep (default: 3)
- `WEBHOOK_URL` - URL to receive backup notifications (set to `""` to disable)

## Webhook Notifications

The script POSTs a JSON notification to `WEBHOOK_URL` on every exit — whether the backup succeeds or fails.

**Payload shape:**
```json
{
  "title": "Proxmox Backup: <hostname>",
  "message": "Backup completed successfully: /backups/pve-host-config_mynode_2026-04-03_04-00-00.tar.gz (42M)",
  "severity": "info",
  "timestamp": 1712173689
}
```

- `severity` is `"info"` on success and `"error"` on any failure (permission denied, tar error, unexpected exit).
- `timestamp` is a Unix epoch integer.

**To disable notifications**, set `WEBHOOK_URL` to an empty string in `config.sh`:
```bash
WEBHOOK_URL=""
```

## Requirements

- Bash shell
- tar with gzip support
- curl (for webhook notifications)
- Standard Unix utilities (find, awk, date)
- Write permissions to backup destination

## Tested Environment

This script has been tested on single node Proxmox VE 8.4.1.

## License

MIT License - Feel free to use and modify as needed.

