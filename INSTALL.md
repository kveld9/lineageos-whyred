# Installation and Flashing Guide

Complete step-by-step installation instructions, recovery setup, and storage configuration for LineageOS 21.0 (Android 14) on Xiaomi Redmi Note 5 Pro / AI (`whyred`).

---

## Prerequisites

Before proceeding with the installation, verify that:
* Bootloader is unlocked (official Xiaomi unlock procedure).
* Host PC has current `adb` and `fastboot` platform tools installed.
* USB debugging is enabled under Developer Options.
* Device battery charge is above 50%.
* All important data is backed up to an external medium (clean flash formats internal storage).

---

## Recommended Filesystem for `/data` (F2FS)

This ROM supports both **F2FS** and **EXT4** for the `/data` partition (`/userdata`).

Due to the internal physical architecture of eMMC 5.1 flash memory, **F2FS (Flash-Friendly File System)** is strongly recommended:
* **Random I/O Throughput:** Significantly higher random write performance compared to EXT4.
* **Database Latency:** Minimizes SQLite commit stalls and app cold-start latencies.
* **Storage Longevity:** Reduces write amplification overhead on aging flash memory cells.

---

## Step-by-Step Installation Walkthrough

### 1. Reboot to Fastboot Mode
Connect the device to your computer via USB and execute:
```bash
adb reboot bootloader
```
*(Alternatively, power off the device and hold `Power + Volume Down` until the Fastboot screen appears).*

### 2. Flash Recovery Image
Flash the LineageOS recovery (or compatible OrangeFox / TWRP recovery):
```bash
fastboot flash recovery recovery.img
fastboot reboot recovery
```

### 3. Flash ROM Package via ADB Sideload
1. On the device recovery screen, navigate to **Apply Update** > **Apply from ADB**.
2. On your host computer, run:
```bash
adb sideload lineage-21.0-*-UNOFFICIAL-whyred.zip
```
*(Note: If Lineage Recovery prompts with "Signature verification failed", choose "Yes" to continue).*

### 4. Reboot Recovery
In Recovery, select **Advanced** > **Reboot to Recovery**.
This reboots the device back into recovery using the newly flashed partition definitions and updated boot kernel flags.

### 5. Format `/data` to F2FS (Mandatory for Clean Install)
To ensure File-Based Encryption (FBE) initializes cleanly with Inline Cryptographic Engine (ICE) support:
1. In Recovery, navigate to **Wipe** (or **Manage Partitions**) > select **Data**.
2. Select **Change File System** > choose **F2FS**.
3. Select **Format Data** and type `yes` to confirm.

### 6. Reboot to System
In Recovery, select **Reboot System Now**.
The initial boot sequence takes approximately 2 to 3 minutes while Android initializes encryption master keys and pre-compiles baseline framework profiles.

---

## Post-Installation Guides

Once the operating system is booted and the initial setup wizard is completed:
* **Rooting & Mount Stealth:** To configure kernel-level root and mount isolation, see [KERNELSU.md](KERNELSU.md).
* **System Debloating:** To safely remove unused telemetry daemons, background handlers, and regional services, see [DEBLOAT.md](DEBLOAT.md).

---

## Related Documentation

* [Main Project Documentation](README.md)
* [KernelSU Next & SuSFS Setup Guide](KERNELSU.md)
* [System Debloating Guide](DEBLOAT.md)
* [Building from Source Guide](BUILD.md)
* [Kernel & Hardware Audit Registry](AUDIT_REGISTRY.md)
