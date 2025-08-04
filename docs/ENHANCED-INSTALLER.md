# Enhanced Installer Documentation

This document describes the improvements made to address UX, tripwire, and GeoIP installation issues.

## Overview of Improvements

### 1. Enhanced Visual UX (`common/lib/ui-helper.sh`)

A new UI helper library provides consistent, visually appealing output:

- **Color-coded messages** with icons/symbols
- **Progress indicators** for long operations
- **Formatted headers** and section dividers
- **Summary boxes** for important information
- **Interactive menus** with better formatting

**Features:**
- Unicode symbols with ASCII fallbacks
- Consistent timestamp formatting
- Error/warning/success indicators
- Progress bars and spinners

### 2. Enhanced Installer (`deploy/install-enhanced.sh`)

The new installer addresses all the feedback points:

**Tripwire Handling:**
- Pre-warns users about interactive key generation
- Explains the two passphrases needed
- Automatically backs up generated keys to `/etc/tripwire/keys-backup/`
- Shows clear instructions on where keys are stored
- Separates interactive output to a dedicated log file

**Improved Logging:**
- Main log: `/var/log/ubuntu-security-toolkit/install-*.log`
- Interactive log: `/var/log/ubuntu-security-toolkit/interactive-*.log`
- Console output remains clean and readable
- Interactive prompts don't interfere with regular logging

**Visual Enhancements:**
- Welcome screen with clear overview
- Section headers for each installation phase
- Real-time progress tracking
- Color-coded success/failure indicators
- Summary statistics at completion

### 3. Fixed GeoIP Installation (`common/fail2ban/f2b-geoban.sh`)

**Improvements:**
- Better error handling for package installation
- Fallback to GitHub mirror for GeoLite2 database
- Graceful degradation if GeoIP unavailable
- Clear warnings instead of cryptic errors
- Country code to name conversion

**Error Recovery:**
- Continues operation even if GeoIP fails
- Shows "Unknown" for countries when database missing
- Validates geoiplookup output before parsing
- Handles multiple output formats

## Usage

### Running the Enhanced Installer

```bash
# Use the enhanced installer for better UX
sudo ./deploy/install-enhanced.sh

# Original installer still available
sudo ./deploy/install-all.sh
```

### Key Differences

1. **Interactive Packages**: Tripwire and similar packages are handled separately
2. **Visual Feedback**: Clear progress indicators and status messages
3. **Error Recovery**: Better handling of partial failures
4. **Key Backup**: Automatic backup of sensitive keys

### Tripwire Keys Location

After installation, Tripwire keys are backed up to:
```
/etc/tripwire/keys-backup/
├── site.key              # Site-wide configuration key
└── hostname-local.key    # Local system key
```

**Important**: Store these keys securely! You'll need them to:
- Update Tripwire policies
- Generate integrity reports
- Re-initialize the database

## Troubleshooting

### GeoIP Issues

If GeoIP lookups show "Unknown":
1. Check if database exists: `ls /usr/share/GeoIP/`
2. Try manual download: `sudo ./common/fail2ban/update-geoip.sh`
3. Verify geoiplookup works: `geoiplookup 8.8.8.8`

### Tripwire Issues

If Tripwire installation fails:
1. Install manually: `sudo apt-get install tripwire`
2. Initialize database: `sudo tripwire --init`
3. Check keys: `ls /etc/tripwire/*.key`

### Log Files

- Installation log: `/var/log/ubuntu-security-toolkit/install-*.log`
- Interactive log: `/var/log/ubuntu-security-toolkit/interactive-*.log`
- Check both for complete picture of installation

## Future Enhancements

1. **Automated Tripwire**: Investigate using expect or similar for full automation
2. **GeoIP Alternative**: Consider IP2Location or other services
3. **Progress Estimation**: Add time estimates for long operations
4. **Rollback Support**: Add ability to undo failed installations