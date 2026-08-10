#!/usr/bin/env bash
# =====================================================================
# efi-mounter: EFI Partition Utility for OS X Yosemite (10.10)
# Repository: https://github.com/EiJackGH/efi-mounter
# =====================================================================

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Centralized Error Dispatcher
raise_error() {
    local CODE="$1"
    local DETAILS="$2"

    echo -e "${RED}[ERROR ${CODE}]${NC} " >&2

    case "$CODE" in
        ERR_100) echo -e "${RED}Operating System Incompatibility: This tool strictly requires OS X / macOS.${NC}" >&2 ;;
        ERR_101) echo -e "${RED}Missing System Dependency: 'diskutil' command not found in system PATH.${NC}" >&2 ;;
        ERR_102) echo -e "${RED}Missing System Dependency: 'df' command not found in system PATH.${NC}" >&2 ;;
        ERR_103) echo -e "${RED}Missing System Dependency: 'awk' or 'sed' text processors missing.${NC}" >&2 ;;
        ERR_200) echo -e "${RED}Null Parameter: No disk identifier provided.${NC}" >&2 ;;
        ERR_201) echo -e "${RED}Invalid Identifier Format: Target '$DETAILS' does not match format 'diskXsY' (e.g., disk0s1).${NC}" >&2 ;;
        ERR_202) echo -e "${RED}Device Not Found: Disk node '/dev/$DETAILS' does not exist in system hardware tree.${NC}" >&2 ;;
        ERR_203) echo -e "${RED}Invalid Partition Type: Disk '$DETAILS' is not a FAT32/EFI formatted partition.${NC}" >&2 ;;
        ERR_300) echo -e "${RED}Boot Drive Detection Failure: Unable to resolve root filesystem '/' device node.${NC}" >&2 ;;
        ERR_301) echo -e "${RED}Parent Disk Parse Error: Unable to extract parent disk ID from node '$DETAILS'.${NC}" >&2 ;;
        ERR_302) echo -e "${RED}Missing EFI Slice: No valid EFI partition slice found on parent disk '$DETAILS'.${NC}" >&2 ;;
        ERR_400) echo -e "${RED}Already Mounted: Partition '/dev/$DETAILS' is already mounted in /Volumes.${NC}" >&2 ;;
        ERR_401) echo -e "${RED}Mount Operation Failed: 'diskutil mount $DETAILS' returned non-zero exit status.${NC}" >&2 ;;
        ERR_402) echo -e "${RED}Permission Denied: Insufficient privilege to mount '/dev/$DETAILS'. Sudo may be required.${NC}" >&2 ;;
        ERR_500) echo -e "${RED}Not Mounted: Partition '/dev/$DETAILS' is not currently mounted.${NC}" >&2 ;;
        ERR_501) echo -e "${RED}Unmount Operation Failed: Volume '$DETAILS' may be busy or locked by another process.${NC}" >&2 ;;
        ERR_502) echo -e "${RED}Force Unmount Required: Resource busy on '/dev/$DETAILS'. Terminate accessing applications.${NC}" >&2 ;;
        ERR_900) echo -e "${RED}Invalid CLI Argument: Unknown option '$DETAILS'. Run with -h for help.${NC}" >&2 ;;
        ERR_901) echo -e "${RED}Invalid Menu Selection: Option '$DETAILS' is out of bounds [1-5].${NC}" >&2 ;;
        *)       echo -e "${RED}Unspecified Critical Execution Error: $DETAILS${NC}" >&2 ;;
    esac

    exit 1
}

verify_environment() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        raise_error "ERR_100"
    fi

    command -v diskutil >/dev/null 2>&1 || raise_error "ERR_101"
    command -v df >/dev/null 2>&1 || raise_error "ERR_102"
    command -v awk >/dev/null 2>&1 || raise_error "ERR_103"
    command -v sed >/dev/null 2>&1 || raise_error "ERR_103"
}

validate_disk_identifier() {
    local DISK="$1"

    if [ -z "$DISK" ]; then
        raise_error "ERR_200"
    fi

    if [[ ! "$DISK" =~ ^disk[0-9]+s[0-9]+$ ]]; then
        raise_error "ERR_201" "$DISK"
    fi

    if ! diskutil info "$DISK" >/dev/null 2>&1; then
        raise_error "ERR_202" "$DISK"
    fi
}

list_efi_partitions() {
    echo -e "${CYAN}[INFO] Scanning for EFI Partitions...${NC}\n"
    if ! diskutil list | grep -E "(TYPE NAME|EFI)"; then
        echo -e "${YELLOW}[WARN] No partitions matching type 'EFI' were detected.${NC}"
    fi
    echo ""
}

auto_mount_primary_efi() {
    echo -e "${CYAN}[INFO] Auto-detecting primary boot drive EFI partition...${NC}"

    local ROOT_NODE
    ROOT_NODE=$(df / 2>/dev/null | tail -n1 | awk '{print $1}' | sed 's|/dev/||') || raise_error "ERR_300"

    if [ -z "$ROOT_NODE" ]; then
        raise_error "ERR_300"
    fi

    local PARENT_DISK
    PARENT_DISK=$(echo "$ROOT_NODE" | sed -E 's/s[0-9]+$//')

    if [ -z "$PARENT_DISK" ] || [ "$PARENT_DISK" = "$ROOT_NODE" ]; then
        raise_error "ERR_301" "$ROOT_NODE"
    fi

    local EFI_PARTITION
    EFI_PARTITION=$(diskutil list "$PARENT_DISK" 2>/dev/null | awk '/EFI/ {print $NF}' | head -n1)

    if [ -z "$EFI_PARTITION" ]; then
        raise_error "ERR_302" "$PARENT_DISK"
    fi

    echo -e "${GREEN}[INFO] Primary boot disk identified: ${PARENT_DISK}${NC}"
    echo -e "${GREEN}[INFO] Primary EFI partition target: ${EFI_PARTITION}${NC}"
    echo ""

    mount_efi "$EFI_PARTITION"
}

mount_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        list_efi_partitions
        read -p "Enter disk identifier to MOUNT (e.g., disk0s1): " TARGET_DISK
    fi

    validate_disk_identifier "$TARGET_DISK"

    # Check if already mounted
    if diskutil info "$TARGET_DISK" | grep -q "Mount Point:[[:space:]]*/"; then
        raise_error "ERR_400" "$TARGET_DISK"
    fi

    echo -e "${YELLOW}[INFO] Attempting to mount /dev/${TARGET_DISK}...${NC}"
    
    local MOUNT_OUT
    if MOUNT_OUT=$(diskutil mount "$TARGET_DISK" 2>&1); then
        echo -e "${GREEN}[SUCCESS] Successfully mounted /dev/${TARGET_DISK} at /Volumes/EFI${NC}"
    else
        if echo "$MOUNT_OUT" | grep -qi "permission"; then
            raise_error "ERR_402" "$TARGET_DISK"
        else
            raise_error "ERR_401" "$TARGET_DISK"
        fi
    fi
}

unmount_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        list_efi_partitions
        read -p "Enter disk identifier to UNMOUNT (e.g., disk0s1): " TARGET_DISK
    fi

    validate_disk_identifier "$TARGET_DISK"

    # Check if volume is mounted before attempting unmount
    if ! diskutil info "$TARGET_DISK" | grep -q "Mount Point:[[:space:]]*/"; then
        raise_error "ERR_500" "$TARGET_DISK"
    fi

    echo -e "${YELLOW}[INFO] Attempting to unmount /dev/${TARGET_DISK}...${NC}"
    
    local UNMOUNT_OUT
    if UNMOUNT_OUT=$(diskutil unmount "$TARGET_DISK" 2>&1); then
        echo -e "${GREEN}[SUCCESS] Successfully unmounted /dev/${TARGET_DISK}.${NC}"
    else
        if echo "$UNMOUNT_OUT" | grep -qi "busy"; then
            raise_error "ERR_502" "$TARGET_DISK"
        else
            raise_error "ERR_501" "$TARGET_DISK"
        fi
    fi
}

show_help() {
    echo -e "${CYAN}OS X Yosemite EFI Mounter Utility${NC}"
    echo "Usage: ./efi-mounter [option] [disk_identifier]"
    echo ""
    echo "Options:"
    echo "  -a, --auto           Auto-detect and mount primary boot disk EFI"
    echo "  -l, --list           List all available EFI partitions"
    echo "  -m, --mount <disk>   Mount specified EFI partition (e.g., disk0s1)"
    echo "  -u, --unmount <disk> Unmount specified EFI partition"
    echo "  -h, --help           Display this help menu"
}

verify_environment

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
            *) raise_error "ERR_901" "$CHOICE" ;;
        esac
        ;;
    *)
        raise_error "ERR_900" "$1"
        ;;
esac
