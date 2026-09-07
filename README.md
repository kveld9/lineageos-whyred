# LineageOS 21.0 for Xiaomi Redmi Note 5 Pro (`whyred`)

Unofficial Android 14 (LineageOS 21.0) port powered by Linux Kernel 4.19 (`4.19.325`) for Xiaomi Redmi Note 5 Pro / AI (`whyred`).

## Device Specifications

| Component | Specification |
| :--- | :--- |
| **SoC** | Qualcomm Snapdragon 660 (SDM660) |
| **CPU** | 8x Kryo 260 (up to 2.2 GHz) |
| **GPU** | Adreno 512 |
| **Memory** | 3 GB / 4 GB / 6 GB LPDDR4X |
| **Storage** | 32 GB / 64 GB eMMC 5.1 |
| **Display** | 1080 x 2160 pixels, 18:9 ratio |
| **Battery** | 4000 mAh |

---

## Project Architecture & Topology

This repository orchestrates the build environment, local manifests, documentation, and tooling. The device-specific trees are versioned in personal forks under `kveld9/*`:

| Component | Path | Upstream Base | Active Fork & Branch |
| :--- | :--- | :--- | :--- |
| **Root Orchestration** | `.` | — | [`kveld9/lineageos-whyred`](https://github.com/kveld9/lineageos-whyred) (`main`) |
| **Device Tree** | `device/xiaomi/whyred` | LineageOS 20 | [`kveld9/android_device_xiaomi_whyred`](https://github.com/kveld9/android_device_xiaomi_whyred) (`lineage-21`) |
| **Vendor Blobs** | `vendor/xiaomi/whyred` | TheMuppets 20 | [`kveld9/proprietary_vendor_xiaomi_whyred`](https://github.com/kveld9/proprietary_vendor_xiaomi_whyred) (`lineage-21`) |
| **Kernel Source** | `kernel/xiaomi/sdm660` | LineageOS 21 | [`kveld9/android_kernel_xiaomi_sdm660`](https://github.com/kveld9/android_kernel_xiaomi_sdm660) (`lineage-21`) |
| **Common Device Tree** | `device/xiaomi/sdm660-common` | LineageOS 21 | Upstream (`lineage-21`) |
| **Common Vendor Tree** | `vendor/xiaomi/sdm660-common` | TheMuppets 21 | Upstream (`lineage-21`) |
| **Build System** | `build/make` | LineageOS 21 | [`kveld9/android_build`](https://github.com/kveld9/android_build) (`lineage-21.0`) |

### Key Technical Details
- **Android Version:** 14 (LineageOS 21.0, `userdebug`)
- **Kernel Version:** Linux 4.19.325 (`Image.gz-dtb`)
- **Platform Security Patch:** August 2026 (`2026-08-01`)
- **Vendor Patch Level:** November 2018 (`2018-11-01`, Qualcomm/Xiaomi proprietary blobs)
- **Partition Layout:** Standard static partitions (non-dynamic, original eMMC partition table)
- **Encryption:** File-Based Encryption (FBE / ICE, `fileencryption=ice`)

---

## Building from Source

### Prerequisites
- Linux host (Arch Linux / Debian / Ubuntu) with 32 GB RAM (or 16 GB + swapfile).
- Android build dependencies, `repo` tool, `git-lfs`, and `ccache`.

### Syncing Sources
```bash
# Initialize LineageOS 21 repo
repo init -u https://github.com/LineageOS/android.git -b lineage-21.0 --git-lfs

# Add local manifest
mkdir -p .repo/local_manifests
cp local_manifests/whyred.xml .repo/local_manifests/whyred.xml

# Sync repos
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j$(nproc)
```

### Compiling
```bash
source build/envsetup.sh
breakfast whyred
m bacon
```

Built artifacts will be generated in `out/target/product/whyred/`:
- `lineage-21.0-*-UNOFFICIAL-whyred.zip` (Flashable ROM zip)
- `boot.img` (Kernel 4.19 + Ramdisk)
- `recovery.img` (LineageOS Recovery)

---

## Flashing Instructions

### Recommended Filesystem for `/data` (F2FS)
This ROM supports both **F2FS** and **EXT4** for `/data` (`/userdata`). 
Due to the architecture of eMMC 5.1 storage, **F2FS (Flash-Friendly File System)** is strongly recommended for significantly better random I/O performance and reduced database write latency.

### Step-by-Step Installation Guide

1. **Reboot to Fastboot Mode**:
   ```bash
   adb reboot bootloader
   ```
2. **Flash Recovery Image**:
   ```bash
   fastboot flash recovery recovery.img
   fastboot reboot recovery
   ```
3. **Flash ROM Package**:
   - In Recovery, select **Apply Update** > **Apply from ADB**:
   ```bash
   adb sideload lineage-21.0-*-UNOFFICIAL-whyred.zip
   ```
4. **Reboot Recovery**:
   - In Recovery, select **Advanced** > **Reboot to Recovery** (ensures all newly flashed partition tables and kernel flags reload).
5. **Format `/data` to F2FS** (Mandatory for FBE migration and maximum I/O performance):
   - In Recovery (OrangeFox / TWRP / Lineage Recovery):
     - Go to **Wipe / Manage Partitions** > select **Data**.
     - Choose **Change File System** > select **F2FS**.
     - Perform **Format Data** (type `yes` to confirm).
6. **Reboot to System**:
   - Reboot device into Android 14. First boot will take 2–3 minutes to initialize encryption keys.

---

## Releases & Downloads
Flashable builds and recovery images are available under [GitHub Releases](https://github.com/kveld9/lineageos-whyred/releases).
