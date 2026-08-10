#!/usr/bin/env bash
# =====================================================================
# efi-mounter Disk Operations Library
# Path: lib/disk.sh
# =====================================================================

verify_environment() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        raise_error "ERR_100"
    fi

    command -v diskutil >/dev/null 2>&1 || raise_error "ERR_101"
    command -v df >/dev/null 2>&1 || raise_error "ERR_102"
    command -v awk >/dev/null 2>&1 || raise_error "ERR_103"
    command -v sed >/dev/null 2>&1 || raise_error "ERR_103"
}

check_opencore_environment() {
    local TARGET_DISK="$1"
    local OC_FOUND=0

    # 1. Inspect NVRAM variables for active OpenCore boot session
    if nvram -p 2>/dev/null | grep -qi "opencore-version"; then
        echo -e "${YELLOW}[WARN] Active OpenCore NVRAM signature detected.${NC}"
        OC_FOUND=1
    fi

    # 2. Inspect target partition mount point for OpenCore directory structure
    if [ -n "$TARGET_DISK" ]; then
        local MOUNT_PT
        MOUNT_PT=$(diskutil info "$TARGET_DISK" 2>/dev/null | awk -F': ' '/Mount Point/ {print $2}' | xargs)
        
        if [ -n "$MOUNT_PT" ] && [ -d "${MOUNT_PT}/EFI/OC" ]; then
            echo -e "${YELLOW}[WARN] OpenCore filesystem structure found at ${MOUNT_PT}/EFI/OC${NC}"
            OC_FOUND=1
        fi
    fi

    return $OC_FOUND
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

    if diskutil info "$DISK" 2>/dev/null | grep -qi "System Volume: Yes"; then
        raise_error "ERR_303"
    fi

    # Perform OpenCore checks
    if check_opencore_environment "$DISK"; then
        echo -e "${YELLOW}[INFO] Running in OpenCore-managed environment...${NC}"
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

    if diskutil info "$TARGET_DISK" | grep -q "Mount Point:[[:space:]]*/"; then
        raise_error "ERR_400" "$TARGET_DISK"
    fi

    echo -e "${YELLOW}[INFO] Attempting to mount /dev/${TARGET_DISK}...${NC}"
    
    local MOUNT_OUT
    if MOUNT_OUT=$(diskutil mount "$TARGET_DISK" 2>&1); then
        echo -e "${GREEN}[SUCCESS] Successfully mounted /dev/${TARGET_DISK}${NC}"
        
        # Post-mount OpenCore check
        if [ -d "/Volumes/EFI/EFI/OC" ]; then
            echo -e "${CYAN}[INFO] OpenCore bootloader detected on mounted volume /Volumes/EFI/EFI/OC${NC}"
        fi
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
