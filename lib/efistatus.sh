#!/usr/bin/env bash
# =====================================================================
# efi-mounter Status & Payload Inspection Library
# Path: lib/efistatus.sh
# =====================================================================

detect_bootloader_payload() {
    local MOUNT_PT="$1"
    local PAYLOADS=()

    if [ -z "$MOUNT_PT" ] || [ ! -d "$MOUNT_PT" ]; then
        echo "N/A (Unmounted)"
        return
    fi

    [ -d "${MOUNT_PT}/EFI/OC" ] || [ -f "${MOUNT_PT}/EFI/OC/OpenCore.efi" ] && PAYLOADS+=("OpenCore")
    [ -d "${MOUNT_PT}/EFI/CLOVER" ] || [ -f "${MOUNT_PT}/EFI/CLOVER/CloverX64.efi" ] && PAYLOADS+=("Clover")
    [ -d "${MOUNT_PT}/EFI/Microsoft" ] && PAYLOADS+=("Windows Bootloader")
    [ -d "${MOUNT_PT}/EFI/APPLE" ] && PAYLOADS+=("Apple Firmware")

    if [ ${#PAYLOADS[@]} -eq 0 ]; then
        if [ -d "${MOUNT_PT}/EFI" ]; then
            echo "Custom/Generic EFI"
        else
            echo "Empty/Raw FAT32"
        fi
    else
        local IFS=", "
        echo "${PAYLOADS[*]}"
    fi
}

get_efi_partition_status() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        list_efi_partitions
        read -p "Enter disk identifier to inspect (e.g., disk0s1): " TARGET_DISK
    fi

    validate_disk_identifier "$TARGET_DISK"

    local DISK_INFO
    DISK_INFO=$(diskutil info "$TARGET_DISK" 2>/dev/null)

    local MOUNT_PT
    MOUNT_PT=$(echo "$DISK_INFO" | awk -F': ' '/Mount Point/ {print $2}' | xargs)

    local VOL_NAME
    VOL_NAME=$(echo "$DISK_INFO" | awk -F': ' '/Volume Name/ {print $2}' | xargs)
    [ -z "$VOL_NAME" ] && VOL_NAME="N/A"

    local TOTAL_SIZE
    TOTAL_SIZE=$(echo "$DISK_INFO" | awk -F': ' '/Disk Size|Total Size/ {print $2}' | awk -F'(' '{print $1}' | xargs)

    local MOUNT_STATUS
    local PAYLOAD

    if [ -n "$MOUNT_PT" ]; then
        MOUNT_STATUS="${GREEN}Mounted (${MOUNT_PT})${NC}"
        PAYLOAD=$(detect_bootloader_payload "$MOUNT_PT")
    else
        MOUNT_STATUS="${YELLOW}Unmounted${NC}"
        PAYLOAD="N/A (Mount required to inspect)"
    fi

    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "${CYAN} Target EFI Partition:${NC} /dev/${TARGET_DISK}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
    echo -e "  Volume Name     : ${VOL_NAME}"
    echo -e "  Partition Size  : ${TOTAL_SIZE:-Unknown}"
    echo -e "  Mount Status    : ${MOUNT_STATUS}"
    echo -e "  Boot Payload    : ${PAYLOAD}"
    echo -e "${CYAN}-----------------------------------------------------${NC}"
}

scan_all_efi_status() {
    echo -e "${CYAN}[INFO] Scanning system for EFI partitions and active payloads...${NC}\n"

    local EFI_LIST
    EFI_LIST=$(diskutil list | awk '/EFI/ {print $NF}')

    if [ -z "$EFI_LIST" ]; then
        echo -e "${YELLOW}[WARN] No EFI partitions found on system.${NC}"
        return
    fi

    printf "%-12s %-12s %-25s %-22s\n" "IDENTIFIER" "STATUS" "MOUNT POINT" "BOOT PAYLOAD"
    printf "%-12s %-12s %-25s %-22s\n" "----------" "------" "-----------" "------------"

    for DISK in $EFI_LIST; do
        local DISK_INFO
        DISK_INFO=$(diskutil info "$DISK" 2>/dev/null)

        local MOUNT_PT
        MOUNT_PT=$(echo "$DISK_INFO" | awk -F': ' '/Mount Point/ {print $2}' | xargs)

        local STATUS_STR="Unmounted"
        local PAYLOAD="N/A"

        if [ -n "$MOUNT_PT" ]; then
            STATUS_STR="Mounted"
            PAYLOAD=$(detect_bootloader_payload "$MOUNT_PT")
        fi

        printf "%-12s %-12s %-25s %-22s\n" "$DISK" "$STATUS_STR" "${MOUNT_PT:--}" "$PAYLOAD"
    done
    echo ""
}

get_single_efi_status() {
    get_efi_partition_status "$@"
}

get_all_efi_status() {
    scan_all_efi_status "$@"
}
