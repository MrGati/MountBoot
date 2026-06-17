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

---

## Installation & Usage (antiX)

```bash
wget raw.githubusercontent.com/MrGati/MountBoot/main/MountBoot.sh
sh MountBoot.sh
```

Follow the prompts. If you're unsure about any option, the defaults are generally fine.

[EXTRA NOTE]: To host a custom ISO file, I usually install an HTTP server application on my phone and share the file via my phone local IP address.

---

- GUI version not done yet, only CLI.

---

Sorry if the github repository history is all messed up, it's my first time using github.
