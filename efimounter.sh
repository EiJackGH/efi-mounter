#!/usr/bin/env bash
# =====================================================================
# efi-mounter: EFI Partition Utility for OS X Yosemite (10.10)
# Repository: https://github.com/EiJackGH/efi-mounter
# =====================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

verify_osx_version() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}❌ Error: This script is intended for OS X / macOS only.${NC}"
        exit 1
    fi
}

list_efi_partitions() {
    echo -e "${CYAN}🔍 Scanning for EFI Partitions...${NC}\n"
    diskutil list | grep -E "(TYPE NAME|EFI)" || true
    echo ""
}

auto_mount_primary_efi() {
    echo -e "${CYAN}🔍 Auto-detecting primary boot drive EFI partition...${NC}"

    # Get root filesystem disk node (e.g., /dev/disk0s2 -> disk0s2)
    local ROOT_NODE
    ROOT_NODE=$(df / | tail -n1 | awk '{print $1}' | sed 's|/dev/||')

    # Extract parent disk identifier (e.g., disk0s2 -> disk0)
    local PARENT_DISK
    PARENT_DISK=$(echo "$ROOT_NODE" | sed -E 's/s[0-9]+$//')

    if [ -z "$PARENT_DISK" ]; then
        echo -e "${RED}❌ Error: Could not determine primary boot drive.${NC}"
        exit 1
    fi

    # Find the EFI partition identifier on the parent disk (e.g., disk0s1)
    local EFI_PARTITION
    EFI_PARTITION=$(diskutil list "$PARENT_DISK" | awk '/EFI/ {print $NF}' | head -n1)

    if [ -z "$EFI_PARTITION" ]; then
        echo -e "${RED}❌ Error: No EFI partition found on primary boot disk (${PARENT_DISK}).${NC}"
        exit 1
    fi

    echo -e "${GREEN}📍 Primary boot disk: ${PARENT_DISK}${NC}"
    echo -e "${GREEN}📍 EFI partition target: ${EFI_PARTITION}${NC}"
    echo ""

    mount_efi "$EFI_PARTITION"
}

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
        echo -e "${RED}❌ Failed to mount /dev/${TARGET_DISK}.${NC}"
        exit 1
    fi
}

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

show_help() {
    echo -e "${CYAN}OS X Yosemite EFI Mounter${NC}"
    echo "Usage: ./efi-mounter [option] [disk_identifier]"
    echo ""
    echo "Options:"
    echo "  -a, --auto           Auto-detect and mount primary boot disk EFI"
    echo "  -l, --list           List all available EFI partitions"
    echo "  -m, --mount <disk>   Mount specified EFI partition (e.g., disk0s1)"
    echo "  -u, --unmount <disk> Unmount specified EFI partition"
    echo "  -h, --help           Display this help menu"
    echo ""
    echo "Examples:"
    echo "  ./efi-mounter -a"
    echo "  ./efi-mounter -m disk0s1"
}

verify_osx_version

case "$1" in
    -a|--auto)
        auto_mount_primary_efi
        ;;
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
        echo -e "${CYAN}=====================================${NC}"
        echo -e "${CYAN}    OS X Yosemite EFI Mounter       ${NC}"
        echo -e "${CYAN}=====================================${NC}"
        echo "1) Auto-mount Primary Boot EFI"
        echo "2) List EFI Partitions"
        echo "3) Mount an EFI Partition"
        echo "4) Unmount an EFI Partition"
        echo "5) Exit"
        echo ""
        read -p "Select option [1-5]: " CHOICE

        case "$CHOICE" in
            1) auto_mount_primary_efi ;;
            2) list_efi_partitions ;;
            3) mount_efi ;;
            4) unmount_efi ;;
            5) exit 0 ;;
            *) echo -e "${RED}Invalid choice.${NC}" ;;
        esac
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac
