#!/bin/bash
# MountBoot - OS Installation Utility v0.1
# This script provides a simple interface to install operating systems using Ventoy
# This script was made especially for antiX Linux (Debian-based). It allows downloading ISOs and setting up bootable disks.
#
# WARNING: This utility is in early development. Use with caution and backup your data.
# Requires: util-linux, wget, tar, parted, dosfstools, exfat-utils/fuse-exfat
#
# Author: [GAT]
# Version: 0.1
# Date: [23/05/2026]

set -e  # Exit on any error

# Global variables
DISK=""          # Selected disk (e.g., /dev/sda)
PARTITION=""
ISO_LINK=""      # URL of the ISO to download
ISO_SIZE_MB=0     # Size of the ISO in MB (calculated later)
VENTOY_SIZE_MB=500          # Approximate size of Ventoy in MB (can vary based on version and configuration)

ISO_plus_VENTOY_SIZE_MB=0    # Approximate size of the ISO and Ventoy in MB
DISK_SIZE_MB=0   # Size of the selected disk in MB (calculated later)
RESERVED_SIZE_MB=0 # Reserved space for the actual OS installation (in MB)

# =============================================================================
# CORE INSTALLATION FUNCTIONS
# =============================================================================

# Function to install Ventoy on the selected disk
install_ventoy() {
    echo "Installing Ventoy to $DISK (this will erase the entire disk)..."

    # Get ISO size
    ISO_SIZE_MB=$(curl -sI "$ISO_LINK" | grep -i Content-Length | awk '{print $2}' | awk '{printf "%.0f", $1/1024/1024}')
    if [ -z "$ISO_SIZE_MB" ]; then
        echo "ERROR: Could not determine ISO size, defaulting to 10 GB."
        ISO_SIZE_MB=10000
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

    echo "Leaving $RESERVED_SIZE_MB MB free for the disk for the OS installation."

    # Force kernel to re-read partition table and wait for udev
    partprobe "$DISK" || true
    sleep 1

    # Mount the Ventoy partition (usually the first partition)
    mkdir -p /mnt/bootiso
    if ! mount "${PARTITION}" /mnt/bootiso; then
        echo "ERROR: Could not mount ${PARTITION}. Make sure exFAT support is installed (exfat-utils/fuse-exfat)"
        exit 1
    fi

    echo "/mnt/bootiso mounted from ${PARTITION}"

    mkdir -p /mnt/bootiso/ventoy/

    cat > /mnt/bootiso/ventoy/Ventoy.json << 'EOF'
{
    "control": [
        { "VTOY_MENU_TIMEOUT": "0" }
    ]
}
EOF

}

# Function to download and configure the ISO
install_iso() {
    # Get ISO size
    ISO_SIZE_MB=$(curl -sI "$ISO_LINK" | grep -i Content-Length | awk '{print $2}' | awk '{printf "%.0f", $1/1024/1024}')
    if [ -z "$ISO_SIZE_MB" ]; then
        echo "ERROR: Could not determine ISO size, defaulting to 10 GB."
        ISO_SIZE_MB=10000
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

# Display available distributions for installation
show_distributions() {
    echo "Please provide the ISO link."
    printf "Enter ISO link: "
    read -r iso_link
    ISO_LINK="$iso_link"
    echo "You entered: $iso_link"
    show_disks
    install_ventoy
    install_iso
    finish
}

# Display available disks for installation
show_disks() {
    echo "Please choose a disk to install Ventoy on:"
    echo ""
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep disk
    echo ""

    while true; do
        printf "Enter desired disk (e.g., sda, sdb): "
        read -r choice

        if [ -z "$choice" ]; then
            echo "Invalid input. Please try again."
            continue
        fi

        if [ -b "/dev/$choice" ]; then
            # Check if it's an NVMe drive
            case "$choice" in
                *nvme*)
                    echo "The automated script detected your DISK as a nvme, is this right? (y/n)"
                    read -r choice2
                    if [ "$choice2" = "y" ]; then
                        PARTITION="/dev/${choice}p1"
                    else
                        PARTITION="/dev/${choice}1"
                    fi
                    ;;
                *)
                    echo "The automated script detected your DISK as a SATA, is this right? (y/n)"
                    read -r choice2
                    if [ "$choice2" = "y" ]; then
                        PARTITION="/dev/${choice}1"
                    else
                        PARTITION="/dev/${choice}p1"
                    fi
                    ;;
            esac
        fi

        if [ -b "/dev/$choice" ]; then
            # Check if disk is mounted and attempt to unmount
            echo ""
            echo "\e[33m WARNING: \e[0m This will ERASE all data on /dev/$choice PERMANENTLY!"
            echo "Are you sure? (y/n)"
            read -r confirmation
            echo ""

            if [ "$confirmation" = "y" ]; then
                echo "You selected /dev/$choice for installation."
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

# Display main menu options
show_main_menu() {
    echo ""
    echo "Please choose an option:"
    echo "  1) Install an OS on your Disk"
    echo "  2) Go to Terminal"
    echo "  3) Notes (Read before using)"
    echo "  4) Reboot"
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
                echo "Entering terminal... To return to the main menu, run 'exit' or 'sh /usr/local/bin/main.sh'."
                /bin/bash
                ;;
            3)
                cat << 'EOF'
Notes:
- This utility is in early development (like really, something like the alpha of the alpha) and may not work properly. Use with caution.
- This is basically just a script on antiX live-boot.
- Make sure to have a stable internet connection for downloading ISOs and Ventoy.
- After installation, you will need to use an external tool to delete the Ventoy partitions (like Minitool Partition Wizard on Windows or GParted on Linux).
- Some ISOs may only work in UEFI mode, so ensure you select the correct boot mode in your BIOS/UEFI settings.
- If you don't know what you're doing, please don't use this version. Wait for a more stable and user friendly release.
- For any issues or feedback, please check the GitHub repository for this project.
- There are still a LOT of features to add and bugs to fix, so please be really careful and make sure you know what you're doing before using this version.

Instructions:
Firstly you'll need to get a link to the ISO you want to install. You can either use a oficial link or just create a http server with your phone with the iso (I usually do this, just search "http server" on google play or app store).
Then you just have to select the disk you want to install on, and the utility will take care of the rest, have fun!

Special thanks to Ventoy developers for their amazing work and contributions to the open-source community. This project wouldn't be possible without their efforts.
EOF
                ;;
            4)
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
