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
    command -v nvram >/dev/null 2>&1 || raise_error "ERR_104"
}

check_root_privinedges() {
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

    # Check for non-EFI filesystem types (HFS+, APFS)
    if echo "$DISK_INFO" | grep -qiE "Type \(Bundle\):[[:space:]]+(hfs|apfs)"; then
        raise_error "ERR_204" "$DISK"
    fi

    # Verify partition size bounds (between ~100MB and ~1GB)
    local SIZE_BYTES
    SIZE_BYTES=$(echo "$DISK_INFO" | awk -F': ' '/Disk Size|Total Size/ {print $2}' | grep -oE '[0-9]+ Bytes' | awk '{print $1}')
    if [ -n "$SIZE_BYTES" ]; then
        if [ "$SIZE_BYTES" -lt 100000000 ] || [ "$SIZE_BYTES" -gt 1073741824 ]; then
            echo -e "${YELLOW}[WARN] Non-standard partition size detected on $DISK (${SIZE_BYTES} bytes).${NC}"
        fi
    fi

    if echo "$DISK_INFO" | grep -qi "System Volume: Yes"; then
        raise_error "ERR_303"
    fi

    if check_opencore_environment "$DISK"; then
        echo -e "${YELLOW}[INFO] Running in OpenCore-managed environment...${NC}"
    fi
}

verify_filesystem_integrity() {
    local TARGET_DISK="$1"
    echo -e "${CYAN}[INFO] Checking filesystem integrity on /dev/${TARGET_DISK}...${NC}"
    
    if ! fsck_msdos -n "/dev/r${TARGET_DISK}" >/dev/null 2>&1; then
        raise_error "ERR_600" "$TARGET_DISK"
    fi
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

    # Check for multiple EFI slices
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
