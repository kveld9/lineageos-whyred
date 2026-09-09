# KernelSU Next & SuSFS Setup Guide

Complete kernel-level root and filesystem stealth integration guide for LineageOS 21.0 on Xiaomi Redmi Note 5 Pro (`whyred`).

---

## Overview

This distribution ships by default with a 100% clean, unrooted stock Linux 4.19 kernel (`boot.img`).

If you require root access while retaining strict security, full namespace isolation, and compatibility with banking and enterprise applications (passing Google Play Integrity and SafetyNet / CTS profile), a pre-patched kernel image (`boot-ksu.img`) is provided in each release.

### Core Security Architecture
* **Kernel-Level Privileges:** KernelSU Next executes root privileges directly within kernel space rather than relying on a userspace su daemon running in background.
* **Kernel-Level Mount Hiding (SuSFS):** Suspicious File System (SuSFS) operates at the Virtual Filesystem (VFS) layer, masking overlayfs mounts, loop devices, and KSU-specific inodes from user space processes and zygote namespaces.
* **SELinux Enforcing Intact:** SELinux remains strictly **Enforcing**. All root operations comply with kernel security context translation, eliminating detection by apps inspecting security state.

---

## Installation Walkthrough

### 1. Flash Pre-Patched Boot Image
Download `boot-ksu.img` from the matching release assets under [Releases](https://github.com/kveld9/lineageos-whyred/releases). Reboot the device to Fastboot mode and flash the image:
```bash
fastboot flash boot boot-ksu.img
fastboot reboot
```

### 2. Install KernelSU Next Manager Companion App
Download the exact matching v3.1.0 companion manager APK:
* **Version:** `v3.1.0`
* **Version Code:** `33024`
* **Asset Name:** `KernelSU_Next_v3.1.0_33024-release.apk`
* **Official Upstream Release:** [KernelSU-Next v3.1.0 Releases](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/v3.1.0)

### 3. Verify Active Status and Stealth
Open the KernelSU Next Manager application on the device.
The status card should indicate:
* **Working:** Yes (Kernel driver active)
* **Kernel:** `4.19.325` with `SuSFS` active

---

## Non-GKI Architecture & Compatibility Ceiling (Linux 4.19)

Whyred (Qualcomm Snapdragon 636 / sdm660 platform family) operates on **Linux Kernel 4.19**, which belongs to the legacy **non-GKI** (Generic Kernel Image) Android architecture:

### Non-GKI vs. GKI 2.0
Starting in Android 12 (Linux 5.10 / 6.1+), Google enforces GKI with standardized KMI (Kernel Module Interface). Modern SuSFS (v2.1+) and recent root frameworks rely heavily on GKI runtime live-patching and modern eBPF/Kprobe facilities. In non-GKI 4.19 kernels, SuSFS must be statically integrated at compile-time using de-inlined manual hooks across core subsystems:
* VFS path resolution and directory traversal (`fs/namei.c`, `fs/readdir.c`).
* Namespace management and mount propagation (`fs/namespace.c`).
* Reboot dispatcher for kernel driver hooking (`kernel/reboot.c`).
* Core SELinux policy hooks and audit masking.

### The Absolute Compatibility Ceiling
* In upstream `KernelSU-Next`, all releases beyond `v3.1.0-legacy-susfs` (such as `v3.2.0-legacy` and legacy `HEAD`) completely removed `CONFIG_KSU_SUSFS` and dropped SuSFS integration.
* In `susfs4ksu`, non-GKI Linux 4.19 is supported only up to **v2.0.0** (newer versions strictly mandate GKI 6.1+).
* Therefore, the combination of **KernelSU Next v3.1.0-legacy-susfs** + **SuSFS v2.0.0** is the absolute highest achievable compatibility ceiling for Linux 4.19 non-GKI.

### Why Manager v3.1.0 (33024) is Required
KernelSU Next v3 completely replaced the legacy `prctl(0xdeadbeef, ...)` communication channel from v0.x/v1.x with a dedicated driver ioctl interface (`versionCode: 33024`). The companion application matched to this interface is **KernelSU Next Manager v3.1.0** (`versionCode: 33024`). Newer managers (such as v3.3.0+) enforce UAPI version 2 (driver version >= 33188) and display permanent UAPI mismatch warning cards when paired with the legacy 33024 driver.

---

## Recommended KernelSU Next Manager Settings

To maintain maximum stealth (bypassing root/mount detection), security, and banking app compatibility (Play Integrity / CTS profile pass), configure the settings in **KernelSU Next Manager** as follows:

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

## Related Documentation

* [Main Project Documentation](README.md)
* [Installation and Flashing Guide](INSTALL.md)
* [System Debloating Guide](DEBLOAT.md)
* [Building from Source Guide](BUILD.md)
* [Kernel & Hardware Audit Registry](AUDIT_REGISTRY.md)
