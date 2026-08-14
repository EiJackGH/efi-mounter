#!/usr/bin/env bash
# =====================================================================
# efi-mounter: Main Entry Point
# Repository: https://github.com/EiJackGH/efi-mounter
# =====================================================================

set -e

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"

if [[ -f "${LIB_DIR}/errors.sh" && -f "${LIB_DIR}/disk.sh" && -f "${LIB_DIR}/efistatus.sh" ]]; then
    source "${LIB_DIR}/errors.sh"
    source "${LIB_DIR}/disk.sh"
    source "${LIB_DIR}/efistatus.sh"
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
    echo "  -s, --status [disk]  Display status & bootloader details for EFI target(s)"
    echo "  -f, --first-aid <disk> Run First Aid (verify & repair) on specified EFI partition"
    echo "  -o, --opencore       Run OpenCore bootloader environment check"
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
    -s|--status)
        if [ -n "$2" ]; then
            get_single_efi_status "$2"
        else
            get_all_efi_status
        fi
        ;;
    -f|--first-aid)
        first_aid_efi "$2"
        ;;
    -o|--opencore)
        echo -e "${CYAN}[INFO] Executing OpenCore Environment Check...${NC}"
        if check_opencore_environment "$2"; then
            echo -e "${GREEN}[RESULT] OpenCore environment/partition detected.${NC}"
        else
            echo -e "${GREEN}[RESULT] No active OpenCore signature found.${NC}"
        fi
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
        echo "5) Check EFI Partition Status"
        echo "6) Run OpenCore Check"
        echo "7) Run EFI First Aid"
        echo "8) Exit"
        echo ""
        read -p "Select option [1-8]: " CHOICE

        case "$CHOICE" in
            1) auto_mount_primary_efi ;;
            2) list_efi_partitions ;;
            3) mount_efi ;;
            4) unmount_efi ;;
            5) get_all_efi_status ;;
            6) check_opencore_environment ;;
            7) first_aid_efi ;;
            8) exit 0 ;;
            *) raise_error "ERR_901" "$CHOICE" ;;
        esac
        ;;
    *)
        raise_error "ERR_900" "$1"
        ;;
esac
