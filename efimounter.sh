#!/usr/bin/env bash
# =====================================================================
# efi-mounter: Main Entry Point
# Repository: https://github.com/EiJackGH/efi-mounter
# =====================================================================

set -e

# Resolve library path relative to script directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

if [[ -f "${LIB_DIR}/errors.sh" && -f "${LIB_DIR}/disk.sh" ]]; then
    source "${LIB_DIR}/errors.sh"
    source "${LIB_DIR}/disk.sh"
else
    echo "[ERROR] Missing library files in ${LIB_DIR}" >&2
    exit 1
fi

show_help() {
    echo -e "${CYAN}OS X Yosemite EFI Mounter Utility${NC}"
    echo "Usage: ./efimounter.sh [option] [disk_identifier]"
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
            2) list_partitions ;;
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
