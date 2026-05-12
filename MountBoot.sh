#!/bin/bash
# MountBoot - OS Installation Utility v0.1
# This script provides a simple interface to install operating systems using Ventoy
# on antiX Linux (Debian-based). It allows downloading ISOs and setting up bootable disks.
#
# WARNING: This utility is in early development. Use with caution and backup your data.
# Requires: util-linux, wget, tar, parted, dosfstools, exfat-utils/fuse-exfat
#
# Author: [GAT]
# Version: 0.1
# Date: [04/27/2026]

set -e  # Exit on any error

# Global variables
DISK=""          # Selected disk (e.g., /dev/sda)
ISO_LINK=""      # URL of the ISO to download
ISO_SIZE_MB=0     # Size of the ISO in MB (calculated later)
VENTOY_SIZE_MB=500          # Approximate size of Ventoy in MB (can vary based on version and configuration)

ISO_plus_VENTOY_SIZE_MB=0    # Approximate size of the ISO and Ventoy in MB
DISK_SIZE_MB=0   # Size of the selected disk in MB (calculated later)
RESERVED_SIZE_MB=0 # Reserved space for the actual OS installation (in MB)

FileSystem="" # File system type of the selected partition (e.g., ext4, ntfs, exfat)
VENTOY_PARTITION="" # Name of the Ventoy partition (e.g., sda1)
PARTITION_SIZE_MB=0 # Used space on the selected partition in MB (calculated later)

PARTITION="" # Partition name (e.g., sda1 or nvme0n1p1)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Nothing to see here!

# =============================================================================
# CORE INSTALLATION FUNCTIONS
# =============================================================================

# Function to install Ventoy on the selected disk
install_ventoy() {
    echo "Installing Ventoy to $DISK (this will erase the entire disk)..."

    # Get ISO size
    ISO_SIZE_MB=$(curl -sI "$ISO_LINK" | grep -i Content-Length | awk '{print $2}' | awk '{printf "%.0f", $1/1024/1024}')
    if [ -z "$ISO_SIZE_MB" ]; then
        echo "ERROR: Could not determine ISO size."
        exit 1
    fi
    ISO_plus_VENTOY_SIZE_MB=$((ISO_SIZE_MB + VENTOY_SIZE_MB))
    echo "ISO size: $ISO_SIZE_MB MB"

    RESERVED_SIZE_MB=$(($DISK_SIZE_MB - $ISO_plus_VENTOY_SIZE_MB))

    # Download latest Ventoy (using a stable version for reliability)
    wget -O /tmp/ventoy.tar.gz https://github.com/ventoy/Ventoy/releases/download/v1.0.99/ventoy-1.0.99-linux.tar.gz
    tar -xzf /tmp/ventoy.tar.gz -C /tmp
    cd /tmp/ventoy-*

    # Install Ventoy with GPT
    ./Ventoy2Disk.sh -i "$DISK" -g -r "$RESERVED_SIZE_MB"

    echo "Leaving $RESERVED_SIZE_MB MB free on the disk for the OS installation."

    # Force kernel to re-read partition table and wait for udev
    partprobe "$DISK" || true
    sleep 1

    # Mount the Ventoy partition (usually the first partition)
    mkdir -p /mnt/bootiso

    # Mount the partition
    if ! mount "${PARTITION}1" /mnt/bootiso; then
        echo "ERROR: Could not mount ${PARTITION}1. Make sure exFAT support is installed (exfat-utils/fuse-exfat)"
        exit 1
    fi

    echo "/mnt/bootiso mounted from ${PARTITION}1."

    mkdir -p /mnt/bootiso/ventoy/

    echo "Do you want to boot the iso throw memdisk?"
    echo "This won't work on Windows ISOs and may not work if your device doesn't have enough RAM."
    printf "Enter choice y/n (default: n): "
    read -r memdisk_choice
    if [ "$memdisk_choice" = "y" ]; then
        echo "Using memdisk to boot the ISO."
            cat > /mnt/bootiso/ventoy/Ventoy.json << 'EOF'
{
    "control": [
        { "VTOY_MENU_TIMEOUT": "0" }
    ],
    "auto_memdisk": [
        "/ISO.iso"
    ]
}
EOF
    else
    echo "Not using memdisk. The ISO will be booted directly from the disk."
        cat > /mnt/bootiso/ventoy/Ventoy.json << 'EOF'
{
    "control": [
        { "VTOY_MENU_TIMEOUT": "0" }
    ]
}
EOF
    fi
}

# Function to download and configure the ISO
install_iso() {
    # Get ISO size
    ISO_SIZE_MB=$(curl -sI "$ISO_LINK" | grep -i Content-Length | awk '{print $2}' | awk '{printf "%.0f", $1/1024/1024}')
    if [ -z "$ISO_SIZE_MB" ]; then
        echo "ERROR: Could not determine ISO size."
        exit 1
    fi
    ISO_plus_VENTOY_SIZE_MB=$((ISO_SIZE_MB + VENTOY_SIZE_MB))
    echo "ISO size: $ISO_SIZE_MB MB"

    # Ensure the Ventoy volume is mounted before downloading
    if ! mountpoint -q /mnt/bootiso; then
        echo "ERROR: Ventoy partition is not mounted at /mnt/bootiso. Aborting."
        exit 1
    fi

    echo "Downloading ISO to the Ventoy partition..."
    wget -O "/mnt/bootiso/ISO.iso" "$ISO_LINK"
    sync

    echo "Installation complete!"
    echo "Unmounting Ventoy partition..."
    umount /mnt/bootiso || true
}

# Function shown after a successful installation
finish() {
    echo "Finished installing iso to $DISK. You can now reboot and select the disk to boot from it."
    echo "Note: Some ISOs only work on UEFI mode (likely Windows ISOs), so make sure to select the correct boot mode in your BIOS/UEFI settings."
    echo -e "\e[33m READ ME: \e[0m Use the custom disk selection on the installation screen to select the free space on the disk. You'll need to use an external tool to delete the Ventoy partitions after installation. You can use something like minitool partition wizard on Windows or GParted on Linux. Maybe I'll add a script (not likely, I would have to do a big system) or more info on github. Maybe..."
    printf "Choose an option:\n  1) Reboot now\n  2) Return to main menu\nEnter choice: "
    read -r choice
    case "$choice" in
        1)
            echo "Rebooting..."
            /sbin/reboot
            ;;
        2)
            echo "Returning to main menu..."
            main
            ;;
        *)
            echo "Invalid option. Returning to main menu..."
            main
            ;;
    esac
}

# =============================================================================
# MENU FUNCTIONS
# =============================================================================

# Sub-menu for Linux distributions
linux_distros() {
    echo "Available Linux distributions for installation:"
    echo "  1) Arch Linux"
    echo "  2) Back to Distribution Menu"

    while true; do
        printf "Enter choice: "
        read -r choice

        case "$choice" in
            1)
                echo "Arch Linux selected."
                ISO_LINK="https://mirror.rackspace.com/archlinux/iso/latest/archlinux-x86_64.iso"
                show_disks
                install_ventoy
                install_iso
                finish
                ;;
            2)
                echo "Returning to Distribution Menu..."
                return
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Sub-menu for Windows ISOs
windows_isos() {
    echo "Note: Not all Windows ISOs may work properly with Ventoy. Compatibility can vary based on the version."
    echo "Available Windows ISOs for installation:"
    echo "  1) Windows 11"
    echo "  2) Back to Distribution Menu"

    while true; do
        printf "Enter choice: "
        read -r choice

        case "$choice" in
            1)
                echo "Windows 11 selected."
                ISO_LINK="https://software-download.microsoft.com/pr/Win11_24H2_v1_English_x64.iso"
                show_disks
                install_ventoy
                install_iso
                finish
                ;;
            2)
                echo "Returning to Distribution Menu..."
                return
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Display available distributions for installation
show_distributions() {
    echo "Which distribution type would you like to install?"
    echo "  1) Linux (Working)"
    echo "  2) Windows (Just use ''Other'' and provide the ISO link, compatibility not guaranteed)"
    echo "  3) Other (Provide your own ISO link - compatibility not guaranteed)"
    echo "  4) Back to Main Menu"

    while true; do
        printf "Enter choice: "
        read -r choice

        case "$choice" in
            1)
                linux_distros
                ;;
            2)
                windows_isos
                ;;
            3)
                echo "Other distribution selected. Please provide the ISO link."
                printf "Enter ISO link: "
                read -r iso_link
                ISO_LINK="$iso_link"
                echo "You entered: $iso_link"
                show_disks
                install_ventoy
                install_iso
                finish
                ;;
            4)
                echo "Returning to Main Menu..."
                return
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Display available disks for installation
show_disks() {
    echo "Please choose a disk to install Ventoy on:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk
    echo ""

    while true; do

        printf "Enter desired disk (e.g., sda, sdb, nvme0n1): "
        read -r choice

        if [ -z "$choice" ]; then
            echo "Invalid input. Please try again."
            continue
        fi

        if [ -b "/dev/$choice" ]; then
            # Check if it's an NVMe drive
            case "$choice" in
                *nvme*)
                    echo "$choice is a NVMe drive. Noted."
                    PARTITION="/dev/${choice}p"
                    ;;
                *)
                    echo "$choice is a standard SATA drive. Noted."
                    PARTITION="/dev/$choice"
                    ;;
            esac

            # Check if disk is mounted and attempt to unmount
            echo ""
            echo "\e[33m WARNING: \e[0m This will ERASE all data on /dev/$choice PERMANENTLY!"
            echo "Are you sure? (y/n)"
            read -r confirmation
            echo ""

            if [ "$confirmation" = "y" ]; then
                echo "You selected /dev/$choice for installation."
                echo "Please wait while we prepare the disk..."
                parted "/dev/$choice" --script mklabel gpt || true
                DISK="/dev/$choice"
                DISK_SIZE_MB=$(blockdev --getsize64 "$DISK")
                DISK_SIZE_MB=$((DISK_SIZE_MB / 1024 / 1024))
                return
            else
                echo "Disk selection cancelled. Returning to distribution menu in 5 seconds."
                sleep 5
                main
            fi
        else
            echo "Error: /dev/$choice not found. Please try again."
        fi
    done
}

# Display available partitions for OS installation
show_partitions() {
    echo "Please choose the main OS partition (usually the biggest):"
    echo ""
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep part
    echo ""

    while true; do
        printf "Enter desired partition (e.g., sda1, sda2, nvme0n1p1): "
        read -r choice

        if [ -z "$choice" ]; then
            echo "Invalid input. Please try again."
            continue
        fi

        if [ ! -b "/dev/$choice" ]; then
            echo "Error: /dev/$choice not found. Please try again."
            continue
        fi

        # Derive the parent disk (e.g., sda1 -> sda, nvme0n1p2 -> nvme0n1)
        disk=$(lsblk -no PKNAME "/dev/$choice")
        if [ -z "$disk" ]; then
            echo "Error: Could not determine parent disk for /dev/$choice."
            continue
        fi

        # Extract the partition number
        part_num=$(cat "/sys/class/block/$choice/partition" 2>/dev/null)
        if [ -z "$part_num" ]; then
            echo "Error: Could not determine partition number for $choice."
            continue
        fi

        # Unmount if mounted
        if mount | grep -q "/dev/$choice"; then
            echo "Partition /dev/$choice is mounted. Attempting to unmount..."
            if ! umount "/dev/$choice"; then
                echo "Error: Could not unmount /dev/$choice. Aborting."
                continue
            fi
        fi

        echo "You selected /dev/$choice (partition $part_num on /dev/$disk)."

        # Remove Ventoy partitions (VENTOY and VTOYEFI) before repartitioning
        for label in VENTOY VTOYEFI; do
            ventoy_part=$(lsblk -o NAME,LABEL | awk -v lbl="$label" '$2 == lbl {print $1}')
            if [ -n "$ventoy_part" ]; then
                ventoy_num=$(cat "/sys/class/block/$ventoy_part/partition" 2>/dev/null)
                if [ -z "$ventoy_num" ]; then
                    echo "Warning: Could not get partition number for $ventoy_part. Skipping."
                    continue
                fi
                echo "Removing $label partition: /dev/$ventoy_part (partition $ventoy_num on /dev/$disk)..."
                if ! parted "/dev/$disk" --script rm "$ventoy_num"; then
                    echo "Warning: Failed to remove $label partition. Continuing anyway."
                fi
            fi
        done

        # Report filesystem
        filesystem=$(blkid -o value -s TYPE "/dev/$choice")
        echo "Filesystem on /dev/$choice: ${filesystem:-unknown}"

        # Move unallocated space adjacent to the target partition, then extend into it.
        # We use a bounded loop to avoid infinite spinning on unexpected layouts.
        max_iterations=20
        iteration=0
        while parted "/dev/$disk" --script unit MB print free | grep -q "Free Space"; do
            iteration=$(( iteration + 1 ))
            if [ "$iteration" -gt "$max_iterations" ]; then
                echo "Error: Could not consolidate free space after $max_iterations attempts. Check disk layout."
                return 1
            fi

            # Find the partition immediately before a free-space block and shrink it
            # to push free space toward the target partition.
            adjacent_part=$(parted "/dev/$disk" --script unit MB print free \
                | awk '/Free Space/{found=1; next} found{print $1; exit}')

            if [ -z "$adjacent_part" ]; then
                echo "Error: Could not identify partition adjacent to free space."
                return 1
            fi

            if [ "$adjacent_part" = "$part_num" ]; then
                # Free space is already next to our target — stop shuffling.
                break
            fi

            echo "Shuffling: moving free space past partition $adjacent_part..."
            if ! parted "/dev/$disk" --script resizepart "$adjacent_part" 100%; then
                echo "Error: Failed to resize partition $adjacent_part."
                return 1
            fi
        done

        # Extend the target partition into all remaining free space
        echo "Extending /dev/$choice to use all available free space..."
        if ! parted "/dev/$disk" --script resizepart "$part_num" 100%; then
            echo "Error: Failed to extend /dev/$choice."
            return 1
        fi

        echo "Done. /dev/$choice has been extended successfully."
        break
    done
}

# Display main menu options
show_main_menu() {
    echo ""
    echo "Please choose an option:"
    echo "  1) Install an OS on your Disk"
    echo "  2) After Installation (Not done yet, don't use.)"
    echo "  3) Go to Terminal"
    echo "  4) Notes (Read before using)"
    echo "  5) Reboot"
}

# =============================================================================
# MAIN PROGRAM
# =============================================================================

# Main program loop
main() {
    clear
    echo "Good Morning! Running MountBoot v0.1 on antiX Linux (Debian-based)"
    echo ""
    echo "Info: This utility is still in early development and may not work properly."
    echo "Use with caution and at your own risk. Always backup your data before proceeding with any disk operations."
    echo "To go to the terminal, press Ctrl+C or choose option 3. To return to the main menu, simply run 'sh /usr/local/bin/main.sh'."
    echo "You may need the terminal to connect to the internet."

    while true; do
        show_main_menu
        printf "Enter choice: "
        read -r choice

        case "$choice" in
            1)
                echo "You chose to install an OS."
                show_distributions
                ;;
            2)
                echo "After installation, you will need to use an external tool to delete the Ventoy partitions (like Minitool Partition Wizard on Windows or GParted on Linux)."
                echo "Make sure to select the free space on the disk during the OS installation. If you don't, you may run into issues with the installation."
                echo "After deleting the Ventoy partitions, you can proceed with the OS installation as normal."
                ;;
            3)
                echo "Entering terminal... To return to the main menu, run 'exit' or 'sh /usr/local/bin/main.sh'."
                /bin/bash
                ;;
            4)
                echo "Notes:"
                echo " - This utility is in early development (like really, something like the alpha of the alpha) and may not work properly. Use with caution."
                echo " - This is basically just a script on antiX live-boot."
                echo " - Make sure to have a stable internet connection for downloading ISOs and Ventoy."
                echo " - After installation, you will need to use an external tool to delete the Ventoy partitions (like Minitool Partition Wizard on Windows or GParted on Linux)."
                echo " - Some ISOs may only work in UEFI mode, so ensure you select the correct boot mode in your BIOS/UEFI settings."
                echo " - If you don't know what you're doing, please don't use this version. Wait for a more stable and user friendly release."
                echo " - For any issues or feedback, please check the GitHub repository for this project."
                echo " - There are still a LOT of features to add and bugs to fix, so please be really careful and make sure you know what you're doing before using this version."
                echo ""
                echo "Special thanks to miniX and Ventoy developers for their amazing work and contributions to the open-source community. This project wouldn't be possible without their efforts."
                ;;
            5)
                echo "Rebooting..."
                /sbin/reboot
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Run main program
main

# =============================================================================
# To do later:
#
# - Either more info in how to use partition wizard and gparted to delete the Ventoy 
#   partitions after the installation on github, or a script to do it (not likely, 
#   would have to do a big system).
#
# - Be able to choose the iso from a partition on the disk instead of downloading it.
#
# - Save folders and files to a separate partition (There will be a text file 
#   on that partition telling where each file should go, and the script will 
#   move them to the correct location on the Ventoy partition).
#
# - Add more ISO's and distributions.
#
# - Make a second version of this app with a GUI
#
# =============================================================================