#!/usr/bin/env bash
# =====================================================================
# efi-mounter: EFI Partition Utility for OS X Yosemite (10.10)
# Repository: https://github.com/YourUsername/efi-mounter
# =====================================================================

set -e

# Color definitions
RED='\030[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check Yosemite / OS X compatibility
verify_osx_version() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}❌ Error: This script is intended for OS X / macOS only.${NC}"
        exit 1
    fi
}

# List all EFI partitions on the system
list_efi_partitions() {
    echo -e "${CYAN}🔍 Scanning for EFI Partitions...${NC}\n"
    diskutil list | grep -E "(TYPE NAME|EFI)" || true
    echo ""
}

# Mount an EFI partition
mount_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        list_efi_partitions
        read -p "Enter disk identifier to MOUNT (e.g., disk0s1): " TARGET_DISK
    fi

    if [ -z "$TARGET_DISK" ]; then
        echo -e "${RED}❌ Error: No disk identifier provided.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}⚙️ Mounting /dev/${TARGET_DISK}...${NC}"
    if diskutil mount "$TARGET_DISK"; then
        echo -e "${GREEN}✅ Successfully mounted /dev/${TARGET_DISK} at /Volumes/EFI${NC}"
    else
        echo -e "${RED}❌ Failed to mount /dev/${TARGET_DISK}. Ensure the disk identifier is correct.${NC}"
        exit 1
    fi
}

# Unmount an EFI partition
unmount_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        list_efi_partitions
        read -p "Enter disk identifier to UNMOUNT (e.g., disk0s1): " TARGET_DISK
    fi

    if [ -z "$TARGET_DISK" ]; then
        echo -e "${RED}❌ Error: No disk identifier provided.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}⚙️ Unmounting /dev/${TARGET_DISK}...${NC}"
    if diskutil unmount "$TARGET_DISK"; then
        echo -e "${GREEN}✅ Successfully unmounted /dev/${TARGET_DISK}${NC}"
    else
        echo -e "${RED}❌ Failed to unmount /dev/${TARGET_DISK}.${NC}"
        exit 1
    fi
}

# Show CLI Usage
show_help() {
    echo -e "${CYAN}OS X Yosemite EFI Mounter${NC}"
    echo "Usage: ./efi-mounter [option] [disk_identifier]"
    echo ""
    echo "Options:"
    echo "  -l, --list           List all available EFI partitions"
    echo "  -m, --mount <disk>   Mount specified EFI partition (e.g., disk0s1)"
    echo "  -u, --unmount <disk> Unmount specified EFI partition"
    echo "  -h, --help           Display this help menu"
    echo ""
    echo "Examples:"
    echo "  ./efi-mounter -l"
    echo "  ./efi-mounter -m disk0s1"
    echo "  ./efi-mounter -u disk0s1"
}

# Main Execution Routing
verify_osx_version

case "$1" in
    -l|--list)
        list_efi_partitions
        ;;
    -m|--mount)
        mount_efi "$2"
        ;;
    -u|--unmount)
        unmount_efi "$2"
        ;;
    -h|--help)
        show_help
        ;;
    "")
        # Interactive mode if no flags are passed
        echo -e "${CYAN}=====================================${NC}"
        echo -e "${CYAN}    OS X Yosemite EFI Mounter       ${NC}"
        echo -e "${CYAN}=====================================${NC}"
        echo "1) List EFI Partitions"
        echo "2) Mount an EFI Partition"
        echo "3) Unmount an EFI Partition"
        echo "4) Exit"
        echo ""
        read -p "Select option [1-4]: " CHOICE

        case "$CHOICE" in
            1) list_efi_partitions ;;
            2) mount_efi ;;
            3) unmount_efi ;;
            4) exit 0 ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac
