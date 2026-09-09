# LineageOS 21.0 for Xiaomi Redmi Note 5 Pro (`whyred`)

Unofficial Android 14 (LineageOS 21.0) port powered by Linux Kernel 4.19 (`4.19.325`) for Xiaomi Redmi Note 5 Pro / AI (`whyred`).

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

### Repository Structure

```text
lineageos-whyred/
├── local_manifests/
│   └── whyred.xml             # Local manifest mapping personal forks into AOSP tree
├── build_whyred.sh            # Unified ROM and KernelSU build automation script
├── build_ksu_boot.sh          # Dedicated KernelSU Next boot image build script
├── debloat_whyred.sh          # Modular ADB debloater (102 safe packages for user 0)
├── publish_release.sh         # GitHub Release asset publisher & checksum generator
├── README.md                  # Central repository documentation and navigation
├── INSTALL.md                 # Step-by-step flashing & F2FS storage setup guide
├── KERNELSU.md                # KernelSU Next & SuSFS stealth configuration guide
├── DEBLOAT.md                 # Comprehensive 102-package debloat registry & rationale
├── BUILD.md                   # Source synchronization & build environment guide
├── AUDIT_REGISTRY.md          # Hardware diagnostics & kernel audit telemetry
└── AGENTS.md                  # Autonomous engineering & repository protocol
```

### Technical Platform Stack

* **Operating System & Userspace (AOSP / LineageOS):**
  * **Android Version:** 14 (LineageOS 21.0, production `user` build).
  * **Security Patch Level:** August 2026 (`2026-08-01` platform patch / November 2018 vendor patch).
  * **Display & Compositor:** SurfaceFlinger Gaussian background blur disabled (`ro.surface_flinger.supports_background_blur=0`, `persist.sys.sf.disable_blurs=1`), offloading translucent UI scrims to Qualcomm MDP5 Hardware Composer (HWC) to prevent GPU fillrate saturation on Adreno 509 and guarantee consistent 60 fps rendering without dropped frames.
  * **UI Animation Responsiveness:** Default animation speed scales tuned out-of-the-box to **`0.6x`** across window animations (`window_animation_scale`), transitions (`transition_animation_scale`), and animator durations (`animator_duration_scale`), eliminating standard AOSP 1.0x latency while preserving smooth visual feedback.
  * **Zero-Bloat Baseline:** Pure AOSP framework free from vendor MIUI/HyperOS analytics and background telemetry daemons.

* **Kernel & Core Subsystems (Linux 4.19):**
  * **Kernel Architecture:** Linux Kernel 4.19 LTS (`4.19.325`, `Image.gz-dtb`) backport for Qualcomm Snapdragon 636 (SDM636, sdm660 platform family).
  * **CPU & GPU Scheduling:** Energy Aware Scheduling (EAS) calibrated for 4x Gold + 4x Silver Kryo 260 cores and Adreno 509 GPU.
  * **Networking (TCP):** Sockets preserve congestion window across idle intervals (`tcp_slow_start_after_idle=0`, RFC 2861) to eliminate latency stalls during interactive mobile browsing.

* **Security, Encryption & Storage:**
  * **SELinux Enforcement:** Strict **Enforcing** mode with comprehensive sepolicy compliance; zero permissive shortcuts.
  * **Storage Encryption:** File-Based Encryption (FBE) accelerated by Qualcomm Inline Cryptographic Engine (ICE).
  * **Filesystem:** Flash-Friendly File System (**F2FS**) recommended on `/data` to mitigate eMMC 5.1 random write latency.
  * **Cryptographic Keys:** Signed with private RSA 2048-bit release keys passing Play Integrity (`MEETS_DEVICE_INTEGRITY`).

* **Root & Stealth Subsystem (Optional Variant):**
  * **KernelSU Next v3.1.0:** Kernel-level privilege management via dedicated driver ioctl interface (`versionCode: 33024`).
  * **SuSFS v2.0.0:** VFS-level mount isolation masking `/debug_ramdisk`, loop devices, and overlayfs from app and Zygote namespaces.

### Documentation & Guides

| Guide | Scope |
| :--- | :--- |
| [Installation & Flashing Guide](INSTALL.md) | Clean flash walkthrough, recovery setup, and F2FS filesystem configuration |
| [KernelSU Next & SuSFS Setup](KERNELSU.md) | Stable LTS root installation, Linux 4.19 compatibility ceiling, and recommended stealth settings |
| [ReSukiSU & SuSFS Setup](RESUKISU.md) | Bleeding-edge stealth root, multi-manager support, and advanced detection evasion |
| [System Debloating Guide](DEBLOAT.md) | Automated debloat script usage, 102-package registry, and critical apps baseline |
| [Building from Source Guide](BUILD.md) | Host dependencies, repo synchronization, ccache tuning, and build automation |
| [Hardware Audit Registry](AUDIT_REGISTRY.md) | Empirical hardware diagnostics, telemetry logs, benchmarks, and regression gates |

---

## Installation & Flashing

For clean installation and storage formatting:
1. Boot to Fastboot: `adb reboot bootloader`
2. Flash recovery: `fastboot flash recovery recovery.img` and boot into recovery.
3. Sideload ROM: `adb sideload lineage-21.0-*-UNOFFICIAL-whyred.zip`
4. Format `/data` to **F2FS** (Mandatory for FBE migration and maximum I/O performance on eMMC 5.1).
5. Reboot to system.

For the complete step-by-step walkthrough, prerequisites, and troubleshooting, see the dedicated [Installation Guide](INSTALL.md).

---

## Kernel Variants & Root Solutions

This project maintains three parallel Linux 4.19 kernel lines sharing the exact same verified hardware platform foundation:

| Kernel Variant | Boot Image | Role & Philosophy | Companion App |
| :--- | :--- | :--- | :--- |
| **Canonical Stock** (`lineage-21`) | `boot.img` | 100% clean, unrooted upstream LineageOS reference baseline. Included inside ROM zip. | None |
| **KernelSU Next + SuSFS 2.0.0** (`lineage-21-ksu`) | `boot-ksu.img` | Stable LTS daily driver. Manual hooks, proven VFS mount hiding, zero code churn. | [KernelSU Next Manager](https://github.com/KernelSU-Next/KernelSU-Next/releases) |
| **ReSukiSU + SuSFS 2.3.0+** (`lineage-21-resukisu`) | `boot-resukisu.img` | Active bleeding-edge stealth line. Metamodules, multi-manager support, and advanced detection evasion. | [ReSukiSU Manager](https://github.com/ReSukiSU/ReSukiSU/releases) |

### Flashing a Custom Kernel
Flash the desired boot image via fastboot:
```bash
# Option A: Stable LTS Root
fastboot flash boot boot-ksu.img

# Option B: Bleeding-Edge Stealth Root
fastboot flash boot boot-resukisu.img
fastboot reboot
```

For complete configuration and stealth settings, see the dedicated [KernelSU Next Guide](KERNELSU.md) and [ReSukiSU Guide](RESUKISU.md).


---

## System Debloating (ADB)

Although LineageOS 21.0 is significantly leaner than vendor stock firmware (MIUI/HyperOS), the default installation includes background telemetry services, unused daemons, regional authentication handlers, and vestigial frameworks for absent hardware (such as NFC, as `whyred` lacks an NFC controller).

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

This repository provides fully automated pipelines to synchronize upstream LineageOS sources, apply whyred device trees, and build signed release ROM packages and boot images:

```bash
# 1. Compile full LineageOS 21.0 ROM package (bundled with stock boot.img)
./build_whyred.sh --build

# 2. Compile dedicated KernelSU Next + SuSFS boot image (LTS stable)
./build_whyred.sh --build-ksu

# 3. Compile dedicated ReSukiSU + SuSFS boot image (Bleeding-edge stealth)
./build_whyred.sh --build-resukisu

# 4. Publish release assets to GitHub
./publish_release.sh                                # Standard ROM release
./publish_release.sh --kernel-release=resukisu     # Standalone ReSukiSU kernel release

# 5. Full end-to-end pipeline (Build ROM -> Build KSU -> Checksums -> GitHub Release)
./build_whyred.sh --all
```

For host package dependencies, repo synchronization commands, ccache tuning, and artifact specifications, see the dedicated [Building from Source Guide](BUILD.md).

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

