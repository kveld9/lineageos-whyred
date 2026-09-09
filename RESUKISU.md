# ReSukiSU & SuSFS Setup Guide

Advanced stealth kernel-level root and filesystem isolation guide for LineageOS 21.0 on Xiaomi Redmi Note 5 Pro (`whyred`).

---

## Overview

This distribution provides a dedicated bleeding-edge stealth kernel line powered by **ReSukiSU v4.2.0** and **SuSFS v2.3.0** (`boot-resukisu.img`).

While the canonical stock kernel (`boot.img`) remains 100% clean and unrooted, and the KernelSU Next line (`boot-ksu.img`) provides a stable frozen LTS root solution, the **ReSukiSU** variant is built for users requiring the latest root-hiding techniques, advanced stealth hooks, metamodule support, and multi-manager flexibility.

### Core Architecture & Innovations
* **ReSukiSU Driver v4.2.0 (`versionCode: 35115`):** Complete kernel-level root execution with supercall architecture, dynamic module loading filters, and active maintenance.
* **SuSFS v2.3.0 Inline Hooks:** Modern Suspicious File System hooks integrated across the VFS layer (`fs/namei.c`, `fs/namespace.c`, `fs/proc/task_mmu.c`, `fs/proc/cmdline.c`, etc.).
* **Multi-Manager Support (`CONFIG_KSU_MULTI_MANAGER_SUPPORT=y`):** Enables coexistence of multiple managers (ReSukiSU Manager, SukiSU-Ultra, MKSU, RKSU) with independent package names and signatures without security collision.
* **Full SELinux Enforcing:** SELinux remains strictly in **Enforcing** mode with dynamic AVC denial spoofing and policy isolation.
* **WebView Zygote Umount:** Automatic namespace unmounting for WebView Zygote processes, eliminating WebView-based root detection vectors.

---

## Installation Walkthrough

### 1. Flash ReSukiSU Boot Image

#### Option A: Fastboot Mode (Recommended)
Download `boot-resukisu.img` from the release assets under [Releases](https://github.com/kveld9/lineageos-whyred/releases). Reboot the device to Fastboot mode and flash:
```bash
fastboot flash boot boot-resukisu.img
fastboot reboot
```

#### Option B: Recovery Mode (OrangeFox / TWRP)
1. Reboot the device into Recovery mode.
2. Ensure `/vendor` is mounted if flashing manually via shell, or flash `boot-resukisu.img` directly to the `Boot` partition through the Recovery graphical interface.
3. Reboot to System.

---

### 2. Install ReSukiSU Manager Companion App

Download the matching companion manager APK from the official upstream repository:
* **Recommended Companion App:** [ReSukiSU Manager](https://github.com/ReSukiSU/ReSukiSU/releases)
* **Alternative Supported App:** [SukiSU-Ultra Manager](https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases)
* **Latest Official Release:** [ReSukiSU GitHub Releases](https://github.com/ReSukiSU/ReSukiSU/releases)

---

### 3. Verify Active Status and Stealth Telemetry

Open the **ReSukiSU Manager** app on your device.
The status card should indicate:
* **Status:** Working (Kernel driver active)
* **Driver Version:** `35115` (`v4.2.0-in-tree@ReSukiSU`)
* **SuSFS Version:** `v2.3.0` (Active)
* **SELinux Mode:** Enforcing

You can also verify from an ADB shell:
```bash
# Verify active kernel release
uname -a
# Expected: 4.19.325-cip132-st16-perf-resukisu-...

# Verify root context
su -c id
# Expected: uid=0(root) gid=0(root) groups=0(root) context=u:r:ksu:s0
```

---

## ReSukiSU vs. KernelSU Next: Comparative Matrix

| Capability / Dimension | KernelSU Next (`boot-ksu.img`) | ReSukiSU (`boot-resukisu.img`) |
| :--- | :--- | :--- |
| **Driver Base** | KernelSU-Next v3.1.0 (`33024`) | ReSukiSU v4.2.0 (`35115`) |
| **SuSFS Version** | v2.0.0 (Legacy non-GKI patch) | v2.3.0 (Full inline hooks) |
| **Lifecycle State** | Frozen LTS (Rock-solid daily driver) | Active Evolution (Continuous updates) |
| **Multi-Manager Support** | No (Single companion app binding) | Yes (Multiple managers permitted) |
| **WebView Zygote Umount** | Basic zygote umount | Dedicated WebView Zygote isolation |
| **Metamodules Support** | Limited | Native |
| **Companion App** | [KernelSU Next Manager v3.1.0](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/v3.1.0) | [ReSukiSU Manager](https://github.com/ReSukiSU/ReSukiSU/releases) |

---

## Recommended Manager Settings

To ensure maximum stealth, security, and banking app compatibility (passing Google Play Integrity and SafetyNet / MEETS_DEVICE_INTEGRITY):

| Setting / Feature | Recommended State | Technical Rationale |
| :--- | :--- | :--- |
| **Umount modules by default** | **ENABLED (ON)** | Unmounts overlayfs and module paths in non-root application namespaces. Critical for app isolation. |
| **Kernel Umount** | **ENABLED (ON)** | Preserves kernel-level unmounting for Zygote and app processes. Must remain active. |
| **WebView Zygote Umount** | **ENABLED (ON)** | Automatically isolates WebView rendering processes from root mounts. |
| **SELinux Mode** | **ENFORCING** | Keeps kernel SELinux security active. Never set to Permissive on production devices. |
| **AVC Spoofing / Logging Mask** | **ENABLED (ON)** | Intercepts and masks audit denial messages in kernel log buffers. |
| **Su Compatibility Mode** | **ENABLED (ON)** | Provides standard `/system/bin/su` path for root-authorized applications. |

---

## Related Documentation

* [Main Project Documentation](README.md)
* [KernelSU Next Setup Guide](KERNELSU.md)
* [Installation and Flashing Guide](INSTALL.md)
* [Building from Source Guide](BUILD.md)
* [Kernel & Hardware Audit Registry](AUDIT_REGISTRY.md)
