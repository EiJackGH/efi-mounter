#!/usr/bin/env bash
# =====================================================================
# efi-mounter Disk Operations Library
# Path: lib/disk.sh
# =====================================================================

AUTO_REPAIR=${AUTO_REPAIR:-false}

check_sip_status() {
    if command -v csrutil >/dev/null 2>&1; then
        local SIP_STATUS
        SIP_STATUS=$(csrutil status 2>/dev/null)
        if echo "$SIP_STATUS" | grep -qiE "status:[[:space:]]*enabled|nvram.*enabled|raw disk.*enabled"; then
            raise_error "ERR_106"
        fi
    fi
}

verify_environment() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        raise_error "ERR_100"
    fi

    command -v diskutil >/dev/null 2>&1 || raise_error "ERR_101"
    command -v df >/dev/null 2>&1 || raise_error "ERR_102"
    command -v awk >/dev/null 2>&1 || raise_error "ERR_103"
    command -v sed >/dev/null 2>&1 || raise_error "ERR_103"
    command -v nvram >/dev/null 2>&1 || raise_error "ERR_104"

    check_sip_status
}

check_root_privileges() {
    if [ "$EUID" -ne 0 ]; then
        raise_error "ERR_105"
    fi
}

validate_disk_identifier() {
    local DISK="$1"

    if [ -z "$DISK" ]; then
        raise_error "ERR_200"
    fi

    if [[ ! "$DISK" =~ ^disk[0-9]+s[0-9]+$ ]]; then
        raise_error "ERR_201" "$DISK"
    fi

    local DISK_INFO
    if ! DISK_INFO=$(diskutil info "$DISK" 2>/dev/null); then
        raise_error "ERR_202" "$DISK"
    fi

    if echo "$DISK_INFO" | grep -qiE "Type \(Bundle\):[[:space:]]+(hfs|apfs)"; then
        raise_error "ERR_204" "$DISK"
    fi

    if echo "$DISK_INFO" | grep -qi "System Volume: Yes"; then
        raise_error "ERR_303"
    fi
}

check_opencore_environment() {
    local TARGET_DISK="${1:-disk0s1}"
    if nvram -p 2>/dev/null | grep -q "4D1FDA02-38C7-4A6A-9CC6-4BCCD8EA63C0"; then
        return 0
    fi
    return 1
}

repair_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        read -p "Enter EFI partition identifier to repair (e.g., disk0s1): " TARGET_DISK
    fi

    validate_disk_identifier "$TARGET_DISK"
    check_root_privileges

    echo -e "${CYAN}[INFO] Running fsck_msdos automated repair on /dev/r${TARGET_DISK}...${NC}"

    if fsck_msdos -fy "/dev/r${TARGET_DISK}"; then
        echo -e "${GREEN}[SUCCESS] Filesystem repair completed successfully for /dev/${TARGET_DISK}.${NC}"
        return 0
    else
        echo -e "${RED}[ERROR] fsck_msdos failed to resolve filesystem corruption on /dev/${TARGET_DISK}.${NC}" >&2
        return 1
    fi
}

mount_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        read -p "Enter EFI partition identifier (e.g., disk0s1): " TARGET_DISK
    fi

    validate_disk_identifier "$TARGET_DISK"

    # Check if already mounted
    if diskutil info "$TARGET_DISK" 2>/dev/null | grep -q "Mount Point:[[:space:]]*/"; then
        raise_error "ERR_400" "$TARGET_DISK"
    fi

    # Check for target directory collision (/Volumes/EFI)
    if [ -d "/Volumes/EFI" ] && [ "$(ls -A /Volumes/EFI 2>/dev/null)" ]; then
        raise_error "ERR_403"
    fi

    echo -e "${CYAN}[INFO] Attempting to mount /dev/${TARGET_DISK}...${NC}"

    local MOUNT_OUTPUT
    if ! MOUNT_OUTPUT=$(diskutil mount "$TARGET_DISK" 2>&1); then
        if echo "$MOUNT_OUTPUT" | grep -qiE "permission|denied|root"; then
            raise_error "ERR_402" "$TARGET_DISK"
        elif echo "$MOUNT_OUTPUT" | grep -qiE "failed to mount|corrupt|damaged|unable to mount"; then
            if [ "$AUTO_REPAIR" = true ]; then
                echo -e "${YELLOW}[WARN] Mount error encountered (ERR_404). Triggering automated filesystem repair...${NC}"
                if repair_efi "$TARGET_DISK"; then
                    echo -e "${CYAN}[INFO] Retrying mount operation for /dev/${TARGET_DISK}...${NC}"
                    if diskutil mount "$TARGET_DISK" >/dev/null 2>&1; then
                        echo -e "${GREEN}[SUCCESS] EFI partition /dev/${TARGET_DISK} repaired and mounted successfully.${NC}"
                        return 0
                    fi
                fi
            fi
            raise_error "ERR_404" "$TARGET_DISK"
        else
            raise_error "ERR_401" "$TARGET_DISK"
        fi
    fi

    echo -e "${GREEN}[SUCCESS] EFI partition /dev/${TARGET_DISK} mounted successfully.${NC}"
}

unmount_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        read -p "Enter EFI partition identifier to unmount (e.g., disk0s1): " TARGET_DISK
    fi

    validate_disk_identifier "$TARGET_DISK"

    if ! diskutil info "$TARGET_DISK" 2>/dev/null | grep -q "Mount Point:[[:space:]]*/"; then
        raise_error "ERR_500" "$TARGET_DISK"
    fi

    echo -e "${CYAN}[INFO] Unmounting /dev/${TARGET_DISK}...${NC}"

    if ! diskutil unmount "$TARGET_DISK" >/dev/null 2>&1; then
        echo -e "${YELLOW}[WARN] Normal unmount failed. Trying force unmount...${NC}"
        if ! diskutil unmount force "$TARGET_DISK" >/dev/null 2>&1; then
            raise_error "ERR_501" "$TARGET_DISK"
        fi
    fi

    echo -e "${GREEN}[SUCCESS] EFI partition /dev/${TARGET_DISK} unmounted successfully.${NC}"
}

list_efi_partitions() {
    echo -e "${CYAN}[INFO] Scanning system for EFI partitions...${NC}\n"
    diskutil list | grep -E "TYPE|EFI" || echo "No EFI partitions found."
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

    local EFI_COUNT
    EFI_COUNT=$(diskutil list "$PARENT_DISK" 2>/dev/null | grep -c "EFI")

    if [ "$EFI_COUNT" -eq 0 ]; then
        raise_error "ERR_302" "$PARENT_DISK"
    elif [ "$EFI_COUNT" -gt 1 ]; then
        raise_error "ERR_305" "$PARENT_DISK"
    fi

    local EFI_PARTITION
    EFI_PARTITION=$(diskutil list "$PARENT_DISK" 2>/dev/null | awk '/EFI/ {print $NF}' | head -n1)

    echo -e "${GREEN}[INFO] Primary boot disk identified: ${PARENT_DISK}${NC}"
    echo -e "${GREEN}[INFO] Primary EFI partition target: ${EFI_PARTITION}${NC}"
    echo ""

    mount_efi "$EFI_PARTITION"
}

first_aid_efi() {
    local TARGET_DISK="$1"

    if [ -z "$TARGET_DISK" ]; then
        list_efi_partitions
        if [ -t 0 ]; then
            read -p "Enter EFI partition identifier for First Aid (e.g., disk0s1): " TARGET_DISK
        else
            raise_error "ERR_200"
        fi
    fi

    validate_disk_identifier "$TARGET_DISK"
    check_root_privileges

    echo -e "${CYAN}[INFO] Starting EFI First Aid for /dev/${TARGET_DISK}...${NC}"

    # Check if mounted
    local IS_MOUNTED=false
    local MOUNT_PT
    MOUNT_PT=$(diskutil info "$TARGET_DISK" 2>/dev/null | awk -F': ' '/Mount Point/ {print $2}' | xargs)

    if [ -n "$MOUNT_PT" ]; then
        IS_MOUNTED=true
        echo -e "${YELLOW}[WARN] Partition /dev/${TARGET_DISK} is currently mounted at ${MOUNT_PT}.${NC}"
        echo -e "${YELLOW}[WARN] For a safe verification/repair, the partition should be unmounted.${NC}"

        local UNMOUNT_CHOICE="n"
        if [ "$AUTO_REPAIR" = true ]; then
            UNMOUNT_CHOICE="y"
        elif [ -t 0 ]; then
            read -p "Would you like to unmount /dev/${TARGET_DISK} now? (y/n): " UNMOUNT_CHOICE
        fi

        if [[ "$UNMOUNT_CHOICE" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}[INFO] Unmounting /dev/${TARGET_DISK}...${NC}"
            if ! diskutil unmount "$TARGET_DISK" >/dev/null 2>&1; then
                echo -e "${YELLOW}[WARN] Normal unmount failed. Trying force unmount...${NC}"
                if ! diskutil unmount force "$TARGET_DISK" >/dev/null 2>&1; then
                    raise_error "ERR_501" "$TARGET_DISK"
                fi
            fi
            echo -e "${GREEN}[SUCCESS] /dev/${TARGET_DISK} unmounted successfully.${NC}"
            IS_MOUNTED=false
        else
            echo -e "${YELLOW}[WARN] Proceeding with verification on a mounted filesystem. Results might be unreliable.${NC}"
        fi
    fi

    echo -e "${CYAN}[INFO] Verifying filesystem integrity on /dev/r${TARGET_DISK}...${NC}"

    # fsck_msdos -n performs read-only checks.
    if fsck_msdos -n "/dev/r${TARGET_DISK}" >/dev/null 2>&1; then
        echo -e "${GREEN}[SUCCESS] Filesystem on /dev/${TARGET_DISK} is CLEAN and healthy.${NC}"

        # Remount if originally mounted
        if [ "$IS_MOUNTED" = false ] && [ -n "$MOUNT_PT" ]; then
            local REMOUNT_CHOICE="n"
            if [ "$AUTO_REPAIR" = true ]; then
                REMOUNT_CHOICE="y"
            elif [ -t 0 ]; then
                read -p "Would you like to remount /dev/${TARGET_DISK}? (y/n): " REMOUNT_CHOICE
            fi

            if [[ "$REMOUNT_CHOICE" =~ ^[Yy]$ ]]; then
                if diskutil mount "$TARGET_DISK" >/dev/null 2>&1; then
                    echo -e "${GREEN}[SUCCESS] /dev/${TARGET_DISK} remounted successfully.${NC}"
                else
                    echo -e "${YELLOW}[WARN] Failed to remount /dev/${TARGET_DISK}.${NC}"
                fi
            fi
        fi
        return 0
    else
        echo -e "${YELLOW}[WARN] Filesystem corruption or dirty bit detected on /dev/${TARGET_DISK}.${NC}"

        local REPAIR_CHOICE="n"
        if [ "$AUTO_REPAIR" = true ]; then
            REPAIR_CHOICE="y"
        elif [ -t 0 ]; then
            read -p "Would you like to attempt automated repair? (y/n): " REPAIR_CHOICE
        fi

        if [[ "$REPAIR_CHOICE" =~ ^[Yy]$ ]]; then
            if repair_efi "$TARGET_DISK"; then
                echo -e "${GREEN}[SUCCESS] First Aid completed: filesystem repaired successfully.${NC}"

                # Remount if originally mounted
                if [ "$IS_MOUNTED" = false ] && [ -n "$MOUNT_PT" ]; then
                    local REMOUNT_CHOICE="n"
                    if [ "$AUTO_REPAIR" = true ]; then
                        REMOUNT_CHOICE="y"
                    elif [ -t 0 ]; then
                        read -p "Would you like to remount /dev/${TARGET_DISK}? (y/n): " REMOUNT_CHOICE
                    fi

                    if [[ "$REMOUNT_CHOICE" =~ ^[Yy]$ ]]; then
                        if diskutil mount "$TARGET_DISK" >/dev/null 2>&1; then
                            echo -e "${GREEN}[SUCCESS] /dev/${TARGET_DISK} remounted successfully.${NC}"
                        else
                            echo -e "${YELLOW}[WARN] Failed to remount /dev/${TARGET_DISK}.${NC}"
                        fi
                    fi
                fi
                return 0
            else
                raise_error "ERR_600" "$TARGET_DISK"
            fi
        else
            raise_error "ERR_600" "$TARGET_DISK"
        fi
    fi
}
