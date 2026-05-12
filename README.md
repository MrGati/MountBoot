# MountBoot 0.1

**Install any OS from a single ISO — just a small USB required.**

MountBoot is a shell script that runs inside a lightweight liveboot environment (designed for [antiX Linux](https://antixlinux.com/)) and lets you install any OS using just a small USB drive. Born out of frustration with a 2 GB pen drive that couldn't hold most modern ISOs, MountBoot automates the process of turning your target disk into a temporary Ventoy drive, installing the ISO onto it, and bootstrapping the full OS installation.

**Alpha software, use at your own risk.** This is a very early proof of concept. Do not use on a disk containing data you care about.

---

## How It Works

1. Runs inside a liveboot (antiX recommended — it's tiny and runs entirely from RAM, so you can remove the USB mid-install)
2. Wipes and reformats your target drive as a Ventoy disk with free space alongside it
3. Downloads and installs the ISO into the Ventoy partition
4. You boot the ISO and install the OS into the free space *(manual partitioning required; some installs may need UEFI mode)*
5. Run the after-install cleanup to delete the Ventoy partitions and merge them into the main OS partition

**Step 5 is not yet implemented.** For now, use an external tool like [GParted](https://gparted.org/) or [MiniTool Partition Wizard](https://www.minitool.com/partition-manager/) to manually merge the partitions after installation.

---

## Why MountBoot Instead of Netboot?

[Netboot](https://netboot.xyz/) is great, but it requires a stable internet connection and a server. MountBoot runs entirely on your local machine — you only need internet access long enough to download the ISO.

**MountBoot is especially useful when:**
- No Netboot server is available on your network
- Your device doesn't support Netboot
- You're installing multiple OS's simultaneously and don't want to overload a shared Netboot server
- You only have a small USB drive (antiX runs in RAM, freeing up the drive mid-install)

---

## Warnings

- **This will wipe your selected disk.** There is no undo.
- You can use pre-linked ISOs bundled with the script or supply your own.
- If you're not comfortable with manual disk partitioning, wait for a more user-friendly release.
- Windows 11 ISOs may not always work. If you run into issues, install Windows 10 first and upgrade afterward.

---

## Installation & Usage (antiX)

```bash
wget https://raw.githubusercontent.com/MrGati/MountBoot/main/MountBoot.sh
sh MountBoot
```

Follow the prompts. If you're unsure about any option, the defaults are generally fine.

---

## Current Features (v0.1)

- Core Ventoy setup and ISO installation workflow (I'm not sure if memdisk is working)
- Arch Linux ISO pre-linked (not recommended using)

---

## Roadmap

- After-install cleanup: auto-delete Ventoy partitions and merge free space into the OS partition
- Support selecting an ISO from an existing partition/disk instead of downloading it
- File preservation: save personal files before wiping, restore them after install
- Expand the pre-linked ISO library
- Custom antiX ISO with MountBoot pre-installed and a friendlier interface

---

## Future Project

A related project is planned that removes the USB requirement entirely, letting you boot and install ISOs directly from your phone onto your PC.
