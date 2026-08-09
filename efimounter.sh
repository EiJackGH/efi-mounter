#!/usr/bin/env bash

# Exit immediately on uncaught error
set -e

# Ensure running on OS X
if [ "$(uname -s)" != "Darwin" ]; then
    echo "❌ Error: This script is designed for OS X (Yosemite 10.10+)."
    exit 1
fi

echo "=================================================="
echo "  OS X Yosemite EFI Mounter                       "
echo "=================================================="
echo ""

# Scan system for EFI partitions using diskutil
echo "🔍 Scanning for EFI partitions..."
EFI_DISKS=$(diskutil list | grep -i "EFI" | awk '{print $NF}')

if [ -z "$EFI_DISKS" ]; then
    echo "❌ No EFI partitions found on attached drives."
    exit 1
fi

# Display detected EFI partitions
echo "Available EFI Partitions:"
echo "--------------------------------------------------"
i=1
declare -a DISK_ARRAY

for disk in $EFI_DISKS; do
    DISK_SIZE=$(diskutil info "$disk" | grep "Disk Size" | awk -F': ' '{print $2}' | xargs)
    PARENT_DISK=$(echo "$disk" | sed 's/s[0-9]*$//')
    MEDIA_NAME=$(diskutil info "$PARENT_DISK" | grep "Device / Media Name" | awk -F': ' '{print $2}' | xargs)
    
    echo "  [$i] $disk (${DISK_SIZE:-Unknown Size}) - ${MEDIA_NAME:-System Drive}"
    DISK_ARRAY[$i]="$disk"
    ((i++))
done
echo "--------------------------------------------------"

# Prompt user for selection
if [ "${#DISK_ARRAY[@]}" -eq 1 ]; then
    CHOICE=1
    echo "💡 Single EFI partition detected ($TARGET_DISK). Auto-selecting..."
else
    read -p "Select partition number to mount [1-$((i-1))]: " CHOICE
fi

TARGET_DISK="${DISK_ARRAY[$CHOICE]}"

if [ -z "$TARGET_DISK" ]; then
    echo "❌ Invalid selection."
    exit 1
fi

echo ""
echo "🚀 Mounting /dev/$TARGET_DISK..."

# Diskutil mount handling for OS X Yosemite
MOUNT_RESULT=$(diskutil mount "$TARGET_DISK" 2>&1)

if echo "$MOUNT_RESULT" | grep -q "Volume.*mounted"; then
    MOUNT_POINT=$(diskutil info "$TARGET_DISK" | grep "Mount Point" | awk -F': ' '{print $2}' | xargs)
    echo "✅ Successfully mounted $TARGET_DISK at: $MOUNT_POINT"
    
    # Open mounted EFI folder in Finder
    if [ -n "$MOUNT_POINT" ] && [ -d "$MOUNT_POINT" ]; then
        echo "📂 Opening volume in Finder..."
        open "$MOUNT_POINT"
    fi
else
    echo "⚠️ System mount failed. Attempting elevated mount via sudo..."
    sudo mkdir -p "/Volumes/EFI_$TARGET_DISK"
    sudo mount -t msdos "/dev/$TARGET_DISK" "/Volumes/EFI_$TARGET_DISK"
    echo "✅ Successfully mounted to /Volumes/EFI_$TARGET_DISK"
    open "/Volumes/EFI_$TARGET_DISK"
fi

echo ""
echo "=================================================="
echo "🎉 Done!"
echo "=================================================="
