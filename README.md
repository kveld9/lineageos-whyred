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
- **Signing & Keys:** Signed with private RSA release keys generated locally in `certs/` (git-ignored and never committed). Third-party builds automatically generate their own isolated keys. Eliminates `test-keys` / public-key warnings in Trust and passes Play Integrity CTS profile.

### Documentation & Guides

| Guide | Scope |
| :--- | :--- |
| [Installation & Flashing Guide](INSTALL.md) | Clean flash walkthrough, recovery setup, and F2FS filesystem configuration |
| [KernelSU Next & SuSFS Setup](KERNELSU.md) | Root installation, Linux 4.19 compatibility ceiling, and recommended stealth settings |
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

## Root: KernelSU Next & SuSFS

This ROM ships with a 100% clean, unrooted stock Linux 4.19 kernel (`boot.img`). If kernel-level root with stealth mount isolation (passing Play Integrity / CTS profile) is required:

1. Flash the pre-patched boot image: `fastboot flash boot boot-ksu.img`
2. Install the matching companion app: **KernelSU Next Manager v3.1.0** (`versionCode: 33024`).

For the complete configuration guide, Linux 4.19 non-GKI compatibility ceiling analysis, and recommended stealth settings, see the dedicated [KernelSU Next & SuSFS Guide](KERNELSU.md).

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

This repository provides fully automated pipelines to synchronize upstream LineageOS sources, apply whyred device trees, and build signed release ROM packages and boot images:

```bash
# 1. Compile full LineageOS 21.0 ROM package
./build_whyred.sh --build

# 2. Compile dedicated KernelSU Next + SuSFS boot image
./build_whyred.sh --build-ksu

# 3. Publish release assets to GitHub
./publish_release.sh

# 4. Full end-to-end pipeline (Build ROM -> Build KSU -> Checksums -> GitHub Release)
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

