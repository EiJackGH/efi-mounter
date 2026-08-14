#!/usr/bin/env bash
# =====================================================================
# efi-mounter Error Dispatcher Library
# Path: lib/errors.sh
# =====================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

raise_error() {
    local CODE="$1"
    local DETAILS="$2"

    echo -e "${RED}[ERROR ${CODE}]${NC} " >&2

    case "$CODE" in
        ERR_100) echo -e "${RED}Operating System Incompatibility: This tool strictly requires OS X / macOS.${NC}" >&2 ;;
        ERR_101) echo -e "${RED}Missing System Dependency: 'diskutil' command not found in system PATH.${NC}" >&2 ;;
        ERR_102) echo -e "${RED}Missing System Dependency: 'df' command not found in system PATH.${NC}" >&2 ;;
        ERR_103) echo -e "${RED}Missing System Dependency: 'awk' or 'sed' text processors missing.${NC}" >&2 ;;
        ERR_104) echo -e "${RED}Missing System Dependency: 'nvram' binary not accessible for bootloader probing.${NC}" >&2 ;;
        ERR_105) echo -e "${RED}Privilege Escalation Required: Operation requires superuser access. Rerun with 'sudo'.${NC}" >&2 ;;
        ERR_200) echo -e "${RED}Null Parameter: No disk identifier provided.${NC}" >&2 ;;
        ERR_201) echo -e "${RED}Invalid Identifier Format: Target '$DETAILS' does not match format 'diskXsY' (e.g., disk0s1).${NC}" >&2 ;;
        ERR_202) echo -e "${RED}Device Not Found: Disk node '/dev/$DETAILS' does not exist in system hardware tree.${NC}" >&2 ;;
        ERR_203) echo -e "${RED}Invalid Partition Type: Disk '$DETAILS' is not a FAT32/EFI formatted partition.${NC}" >&2 ;;
        ERR_204) echo -e "${RED}Incompatible Filesystem: Slice '$DETAILS' contains HFS+/APFS formatting instead of MS-DOS FAT32.${NC}" >&2 ;;
        ERR_205) echo -e "${RED}Non-Standard Partition Size: Partition '$DETAILS' size is outside standard EFI bounds (100MB - 1GB).${NC}" >&2 ;;
        ERR_300) echo -e "${RED}Boot Drive Detection Failure: Unable to resolve root filesystem '/' device node.${NC}" >&2 ;;
        ERR_301) echo -e "${RED}Parent Disk Parse Error: Unable to extract parent disk ID from node '$DETAILS'.${NC}" >&2 ;;
        ERR_302) echo -e "${RED}Missing EFI Slice: No valid EFI partition slice found on parent disk '$DETAILS'.${NC}" >&2 ;;
        ERR_303) echo -e "${RED}System Disk Restriction: A system disk is limited.${NC}" >&2 ;;
        ERR_304) echo -e "${RED}OpenCore Checks Detected: Active OpenCore bootloader environment or partition structure detected.${NC}" >&2 ;;
        ERR_305) echo -e "${RED}Ambiguous EFI Slices: Multiple EFI partitions found on '$DETAILS'. Specify exact slice (e.g., disk0s1).${NC}" >&2 ;;
        ERR_400) echo -e "${RED}Already Mounted: Partition '/dev/$DETAILS' is already mounted in /Volumes.${NC}" >&2 ;;
        ERR_401) echo -e "${RED}Mount Operation Failed: 'diskutil mount $DETAILS' returned non-zero exit status.${NC}" >&2 ;;
        ERR_402) echo -e "${RED}Permission Denied: Insufficient privilege to mount '/dev/$DETAILS'. Sudo may be required.${NC}" >&2 ;;
        ERR_403) echo -e "${RED}Mount Point Collision: Target mount directory '/Volumes/EFI' already exists and is not empty.${NC}" >&2 ;;
        ERR_404) echo -e "${RED}Mount Disk Error: There's a problem mounting your disk '$DETAILS'. Check disk state or repair using First Aid.${NC}" >&2 ;;
        ERR_500) echo -e "${RED}Not Mounted: Partition '/dev/$DETAILS' is not currently mounted.${NC}" >&2 ;;
        ERR_501) echo -e "${RED}Unmount Operation Failed: Volume '$DETAILS' may be busy or locked by another process.${NC}" >&2 ;;
        ERR_502) echo -e "${RED}Force Unmount Required: Resource busy on '/dev/$DETAILS'. Terminate accessing applications.${NC}" >&2 ;;
        ERR_600) echo -e "${RED}Filesystem Corruption: Dirty bit or corrupted allocation table detected on '/dev/$DETAILS'. Run fsck_msdos.${NC}" >&2 ;;
        ERR_900) echo -e "${RED}Invalid CLI Argument: Unknown option '$DETAILS'. Run with -h for help.${NC}" >&2 ;;
        ERR_901) echo -e "${RED}Invalid Menu Selection: Option '$DETAILS' is out of bounds [1-8].${NC}" >&2 ;;
        *)       echo -e "${RED}Unspecified Critical Execution Error: $DETAILS${NC}" >&2 ;;
    esac

    exit 1
}
