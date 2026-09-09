# LineageOS 21.0 for Xiaomi Redmi Note 5 Pro (`whyred`)

Unofficial Android 14 (LineageOS 21.0) port powered by Linux Kernel 4.19 (`4.19.325`) for Xiaomi Redmi Note 5 Pro / AI (`whyred`).

---

## Why LineageOS?

LineageOS was deliberately chosen as the long-term system foundation for `whyred` based on core architectural principles:

- **Architectural Purity & Minimalist Baseline:**
  Unlike vendor stock firmware (MIUI/HyperOS) burdened with intrusive telemetry daemons, analytics tracking, and aggressive background process killing, LineageOS adheres strictly to clean AOSP design. It avoids arbitrary cosmetic hacks and feature bloat that cause memory leaks and degrade responsiveness on mid-range hardware (Snapdragon 660 with eMMC 5.1).

- **Hardware Longevity & Combating Planned Obsolescence:**
  Official OEM support for `whyred` ceased on Android 9 (Pie) running an obsolete Linux 4.4 kernel. LineageOS 21.0 paired with this modernized Linux 4.19 kernel backport elevates this 2018 device to Android 14 with contemporary platform security patches, extending its secure, daily operational lifecycle by nearly a decade.

- **Strict Security & Uncompromised SELinux:**
  Many aftermarket custom ROMs take shortcuts to bypass difficult HAL/vendor bugs by setting SELinux to Permissive, relaxing sepolicy rules, or shipping untrusted binaries. LineageOS maintains an auditable, strictly **Enforcing** SELinux foundation, enabling modern cryptographic storage models (FBE with ICE) and compliance with enterprise security standards.

- **The Deterministic Foundation for KernelSU Next & SuSFS:**
  Achieving root sovereignty without compromising device security or breaking banking applications requires a predictable, standards-compliant userspace. LineageOS’s unadulterated framework serves as the ideal baseline for kernel-level hooking (KernelSU Next v3.1.0) and filesystem stealth (SuSFS v2.0.0), ensuring clean namespace unmounting and total isolation.

- **Upstream Standards & Source-Level Reproducibility:**
  LineageOS establishes the industry standard for device tree modularity (`device/xiaomi/whyred`, `device/xiaomi/sdm660-common`, `vendor/xiaomi/whyred`). Every commit, HAL definition, and overlay is transparent, deterministic, and maintainable directly from source.

---

## Project Architecture & Topology

This repository orchestrates the build environment, local manifests, documentation, and tooling. The device-specific trees are versioned in personal forks under `kveld9/*`:

| Component | Path | Upstream Base | Active Fork & Branch |
| :--- | :--- | :--- | :--- |
| **Root Orchestration** | `.` | — | [`kveld9/lineageos-whyred`](https://github.com/kveld9/lineageos-whyred) (`main`) |
| **Device Tree** | `device/xiaomi/whyred` | LineageOS 20 | [`kveld9/android_device_xiaomi_whyred`](https://github.com/kveld9/android_device_xiaomi_whyred) (`lineage-21`) |
| **Vendor Blobs** | `vendor/xiaomi/whyred` | TheMuppets 20 | [`kveld9/proprietary_vendor_xiaomi_whyred`](https://github.com/kveld9/proprietary_vendor_xiaomi_whyred) (`lineage-21`) |
| **Kernel Source** | `kernel/xiaomi/sdm660` | LineageOS 21 | [`kveld9/android_kernel_xiaomi_sdm660`](https://github.com/kveld9/android_kernel_xiaomi_sdm660) (`lineage-21`, `lineage-21-ksu`) |
| **Common Device Tree** | `device/xiaomi/sdm660-common` | LineageOS 21 | [`kveld9/android_device_xiaomi_sdm660-common`](https://github.com/kveld9/android_device_xiaomi_sdm660-common) (`lineage-21`) |
| **Common Vendor Tree** | `vendor/xiaomi/sdm660-common` | TheMuppets 21 | Upstream (`lineage-21`) |
| **Build System** | `build/make` | LineageOS 21 | [`kveld9/android_build`](https://github.com/kveld9/android_build) (`lineage-21.0`) |

### Key Technical Details
- **Android Version:** 14 (LineageOS 21.0, `user` / `release-keys`)
- **Kernel Version:** Linux 4.19.325 (`Image.gz-dtb`)
- **Platform Security Patch:** August 2026 (`2026-08-01`)
- **Vendor Patch Level:** November 2018 (`2018-11-01`, Qualcomm/Xiaomi proprietary blobs)
- **Partition Layout:** Standard static partitions (non-dynamic, original eMMC partition table)
- **Encryption:** File-Based Encryption (FBE / ICE, `fileencryption=ice`)
- **Signing & Keys:** Private RSA release keys in `certs/` (`releasekey`, `platform`, `shared`, `media`, `networkstack`, `bluetooth`, `sdk_sandbox`, `nfc`, `testkey`). Eliminates `test-keys` / public-key warnings in Trust and passes Play Integrity CTS profile.

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

### Optional: Root with KernelSU Next + SuSFS

This ROM ships with a 100% clean stock unrooted kernel (`boot.img`). If you require root access with clean Play Integrity / SafetyNet pass:

1. **Flash KernelSU Next Boot Image**:
   ```bash
   fastboot flash boot boot-ksu.img
   fastboot reboot
   ```
2. **Install KernelSU Next Manager**:
   - Download the matching v3.1.0 manager APK (version **v3.1.0**, `versionCode: 33024`, `KernelSU_Next_v3.1.0_33024-release.apk`) from official [KernelSU-Next v3.1.0 Releases](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/v3.1.0).
   - Install via ADB:
     ```bash
     adb install -r KernelSU_Next_v3.1.0_33024-release.apk
     ```
3. **Verify SuSFS Integration**:
   - Open KernelSU Next Manager. Status will indicate active root and kernel-level mount hiding via SuSFS.

#### Non-GKI Architecture & Compatibility Ceiling (Linux 4.19)

Whyred (Snapdragon 660) operates on **Linux Kernel 4.19**, which belongs to the legacy **non-GKI** (Generic Kernel Image) Android architecture:

- **Non-GKI vs. GKI 2.0:**
  Starting in Android 12 (Linux 5.10 / 6.1+), Google enforces GKI with standardized KMI (Kernel Module Interface). Modern SuSFS (v2.1+) and recent root frameworks rely heavily on GKI runtime live-patching and modern eBPF/Kprobe facilities. In non-GKI 4.19 kernels, SuSFS must be statically integrated at compile-time using de-inlined manual hooks across core subsystems (VFS in `fs/namei.c`, `fs/readdir.c`, `fs/namespace.c`, reboot dispatcher in `kernel/reboot.c`, and SELinux).
- **The Absolute Compatibility Ceiling:**
  - In upstream `KernelSU-Next`, all versions beyond `v3.1.0-legacy-susfs` (such as `v3.2.0-legacy` and legacy `HEAD`) completely eliminated `CONFIG_KSU_SUSFS` and dropped SuSFS integration.
  - In `susfs4ksu`, non-GKI Linux 4.19 is supported only up to **v2.0.0** (newer versions require GKI 6.1+).
  - Therefore, the combination of **KernelSU Next v3.1.0-legacy-susfs** + **SuSFS v2.0.0** is the absolute highest achievable compatibility ceiling for Linux 4.19 non-GKI.
- **Why Manager v3.1.0 (33024) is Required:**
  KernelSU Next v3 completely replaced the legacy `prctl(0xdeadbeef, ...)` communication channel from v0.x/v1.x with an anonymous-inode file descriptor supercall subsystem (`ksu_install_fd` dispatched via `sys_reboot`). The exact matching companion app is **KernelSU Next Manager v3.1.0** (`versionCode: 33024`). Newer managers (such as v3.3.0) enforce UAPI version 2 (driver version >= 33188) and trigger UAPI version mismatch warnings when paired with the legacy 33024 driver.

#### Recommended KernelSU Next Manager Settings

To maintain maximum stealth (bypassing root/mount detection), security, and banking app compatibility (Play Integrity / CTS pass), configure the settings in **KernelSU Next Manager** as follows:

| Setting / Toggle | Location | Recommended State | Technical Rationale |
| :--- | :--- | :--- | :--- |
| **Umount modules by default** | Settings &rarr; General | **ENABLED (ON)** | Ensures module mount points (`/debug_ramdisk`, overlayfs, and bind mounts) are unmounted by default in non-root app namespaces. Essential for app isolation. |
| **Disable su compat** | Settings &rarr; General | **DISABLED (OFF)** | Leaves `/system/bin/su` active for authorized root apps. Only turn ON as an emergency kill-switch to temporarily revoke all root access without rebooting. |
| **Disable kernel umount** | Settings &rarr; General *(Dev)* | **DISABLED (OFF)** | **CRITICAL**: Turning this ON disables kernel-level unmounting, which directly breaks SuSFS stealth and exposes module mounts to Zygote and app processes. Must remain **OFF** so kernel umount stays active. |
| **Disable avc spoofing** | Settings &rarr; General *(Dev)* | **DISABLED (OFF)** | **CRITICAL**: Turning this ON disables SELinux AVC denial spoofing. Leaving it **OFF** allows KernelSU to intercept and mask audit log context leaks (`avc: denied`), preventing detection by apps inspecting `dmesg`/`logcat`. |
| **SELinux Permissive** | Settings &rarr; General *(Dev)* | **DISABLED (OFF)** | **CRITICAL**: Keeps SELinux in **Enforcing** mode. Permissive mode immediately trips Google Play Integrity (`MEETS_DEVICE_INTEGRITY`) and flags the device in all banking and enterprise applications. |
| **Check updates** | Settings &rarr; Updates | **DISABLED (OFF)** | Prevents the manager from prompting or auto-downloading incompatible newer manager releases (v3.3.0+), which enforce UAPI 2 and generate red warning cards on Linux 4.19. |
| **Developer options** | Settings &rarr; Developer | **ENABLED (ON)** | Enables visibility of low-level kernel toggles (*Disable kernel umount*, *Disable avc spoofing*, *SELinux Permissive*) to inspect and verify their states. |
| **WebView debugging** | Settings &rarr; Developer | **DISABLED (OFF)** | Minimizes attack surface. Only enable temporarily when developing or debugging WebUI components within custom KernelSU modules. |

> **Note on Developer Settings:** In KernelSU Next Manager, advanced toggles (*Disable kernel umount*, *Disable avc spoofing*, and *SELinux Permissive*) only appear in the main settings screen after unlocking developer mode (tapping **Manager version** 7 times under Settings).

---

## System Debloating (ADB)

Although LineageOS 21.0 is significantly leaner than vendor stock firmware (MIUI/HyperOS), the default installation includes background telemetry services, unused daemons, regional authentication handlers, and unused hardware frameworks (such as NFC on `whyred`).

System apps can be safely uninstalled for the primary user (`user 0`) via ADB without root privileges, partition remounting, or filesystem modifications.

### Automated Script (`debloat_whyred.sh`)

A modular, self-contained shell script is provided in the repository root: [`debloat_whyred.sh`](debloat_whyred.sh). It executes in less than one second and handles all **102 safe packages** by default:

```bash
# 1. Debloat all 102 safe packages in one single step
./debloat_whyred.sh

# 2. Preview packages to be debloated without modifying the device (Dry-Run)
./debloat_whyred.sh --dry-run

# 3. Restore / Re-install previously uninstalled packages
./debloat_whyred.sh --restore

# 4. List all registered packages grouped by section
./debloat_whyred.sh --list
```

For the complete 102-package registry with detailed technical justifications, manual ADB commands, and critical apps kept intact, see the dedicated [System Debloating Guide](DEBLOAT.md).

---

## Releases & Downloads
Flashable builds and recovery images are available under [GitHub Releases](https://github.com/kveld9/lineageos-whyred/releases).

---

## Building from Source

### Prerequisites
- Linux host (Arch Linux / Debian / Ubuntu) with 32 GB RAM (or 16 GB + swapfile).
- Android build dependencies, `repo` tool, `git-lfs`, and `ccache`.

### Syncing Sources
```bash
# Clone the orchestration repository
git clone https://github.com/kveld9/lineageos-whyred.git
cd lineageos-whyred

# Initialize LineageOS 21 repo
repo init -u https://github.com/LineageOS/android.git -b lineage-21.0 --git-lfs

# Add local manifest
mkdir -p .repo/local_manifests
cp local_manifests/whyred.xml .repo/local_manifests/whyred.xml

# Sync repos
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j$(nproc)
```

### Compiling & Automated Pipelines

Prepare the environment:
```bash
./build_whyred.sh
```

Available build and automation workflows:
- **Compile ROM only**:
  ```bash
  ./build_whyred.sh --build
  # Or manually: mka bacon
  ```
- **Build KernelSU Next + SuSFS Boot Image**:
  ```bash
  ./build_ksu_boot.sh
  # Or: ./build_whyred.sh --build-ksu
  ```
- **Publish Release to GitHub**:
  ```bash
  ./publish_release.sh
  # Or dry-run: ./publish_release.sh --dry-run
  ```
- **Full End-to-End Pipeline** (Build ROM -> Build KSU Boot -> Generate Checksums & Changelog -> Publish to GitHub):
  ```bash
  ./build_whyred.sh --all
  ```

Built artifacts generated in `out/target/product/whyred/`:
- `lineage-21.0-*-UNOFFICIAL-whyred.zip` (Flashable ROM zip signed with private `release-keys`)
- `boot.img` (Stock Clean Kernel 4.19 + Ramdisk)
- `boot-ksu.img` (KernelSU Next v3.1.0-legacy-susfs + SuSFS v2.0.0 Kernel + Ramdisk)
- `recovery.img` (LineageOS 21 Recovery)
- `sha256sums.txt` (Cryptographic SHA-256 digests for all assets)

---

## Credits & Acknowledgements

This project builds upon the work of the open-source Android, LineageOS, and Linux kernel communities:

- **[The LineageOS Project](https://github.com/LineageOS)**: Base Android 14 operating system distribution and legacy device framework.
- **[Android Open Source Project (AOSP)](https://source.android.com/)**: Foundational operating system code.
- **[Santhosh (user-why-red / San-Kernel)](https://github.com/user-why-red)**: Linux 4.19 scheduler tuning, SDM660 manual KernelSU hooks, and driver fixes.
- **[KernelSU-Next Team](https://github.com/KernelSU-Next/KernelSU-Next)** & **[Weishu (KernelSU)](https://github.com/tiann/KernelSU)**: Kernel-level root privilege framework.
- **[simonpunk (susfs4ksu)](https://github.com/simonpunk/susfs4ksu)**: SuSFS (Suspicious File System) kernel mount isolation framework.
- **Xiaomi Inc. & Qualcomm Technologies**: Device hardware design and board support package.

---

## License & Legal Notices

- **Orchestration & Tools**: Licensed under the [Apache License, Version 2.0](LICENSE).
- **Linux Kernel Source**: Licensed under the [GNU General Public License v2 (GPL-2.0)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).
- **Trademarks**: "Xiaomi", "Redmi", "whyred", "Qualcomm", "Snapdragon", and "Android" are trademarks of their respective copyright holders. This project is an independent community distribution and is not affiliated with, endorsed by, or sponsored by Xiaomi Inc., Qualcomm Technologies, or Google LLC.
- **Proprietary Blobs**: Hardware blobs in vendor submodules are extracted from official factory firmware and maintained solely for device interoperability under fair use principles.
- **Disclaimer**: Installation of third-party operating systems and custom kernels is performed at your own risk. The author and contributors accept no liability for device damage, data loss, or system instability.

