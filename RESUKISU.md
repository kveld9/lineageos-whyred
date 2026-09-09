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

## Recommended ReSukiSU Manager Settings

To ensure maximum stealth (bypassing root and mount detection), system security, and banking app compatibility (passing Google Play Integrity and SafetyNet / `MEETS_DEVICE_INTEGRITY`), configure the settings in **ReSukiSU Manager** as follows:

| Setting / Toggle | Location | Recommended State | Technical Rationale |
| :--- | :--- | :--- | :--- |
| **Module unmounting** | Settings &rarr; Configure | **ENABLED (ON)** | Automatically unmounts overlayfs and module paths in non-root application namespaces. Critical for process isolation. |
| **Classic su command** | Settings &rarr; Configure | **Default / Enabled** | Provides standard `/system/bin/su` path for root-authorized applications. Only disable if acting as an emergency root kill-switch. |
| **Auto jailbreak** | Settings &rarr; Configure | **DISABLED (OFF)** | Prevents newly installed applications from automatically receiving root access without explicit user authorization prompts. |
| **ADB Root** | Settings &rarr; Configure | **DISABLED (OFF)** | Keeps ADB shell unprivileged (`shell`) by default, preventing unauthorized root privilege escalation over USB debugging. |
| **Hide SUS Mounts for Non-SU Procs** | Settings &rarr; SuSFS Config &rarr; Standard Features | **ENABLED (ON)** | **CRITICAL**: Enforces SuSFS kernel-level hiding of all suspicious mount points for non-root processes, bypassing manager umount limits. |
| **AVC Log Spoofing** | Settings &rarr; SuSFS Config &rarr; Standard Features | **ENABLED (ON)** | **CRITICAL**: Spoofs `su` context in kernel audit denial (`avc: denied`) messages to prevent apps from detecting root through audit logs or `dmesg`. |
| **Logging** | Settings &rarr; SuSFS Config &rarr; Standard Features | **DISABLED (OFF)** | Disables SuSFS debug logging to prevent unnecessary I/O overhead on eMMC 5.1 storage and eliminate forensic log artifacts. |
| **SU Log** | Settings &rarr; General | **DISABLED (OFF)** | Avoids writing superuser execution logs to disk, reducing flash memory wear and eliminating local root access trails. |
| **SELinux Permissive** | Settings &rarr; Developer | **DISABLED (OFF)** | **CRITICAL**: Keeps SELinux strictly **Enforcing**. Setting Permissive immediately trips Google Play Integrity and flags the device in financial apps. |
| **Check beta updates** | Settings &rarr; Updates | **DISABLED (OFF)** | Prevents the manager from prompting or auto-installing experimental main-branch builds that may disrupt stability on Linux 4.19. |

### Understanding Home Screen "Seccomp status: Disabled"

In the ReSukiSU Manager Home screen, the status card reports `Seccomp status: Disabled`. This is an **intentional design characteristic** and **not a system defect**:

* **Process-Local Inspection:** The manager inspects Seccomp status strictly for its own calling process via `prctl(PR_GET_SECCOMP)`.
* **Privileged Syscall Unblocking:** On Linux kernels prior to 5.10 (such as Linux 4.19 LTS on `whyred`), the ReSukiSU kernel driver explicitly invokes `disable_seccomp()` for root-authorized processes and the manager itself. This prevents Android's Zygote BPF sandbox from terminating root operations (such as mount manipulation or reboot calls) with `SIGSYS`.
* **System-Wide Sandboxing Active:** All non-root applications and standard userspace services (`system_server`, `SystemUI`, browser, third-party apps) remain strictly enforced under `Seccomp: 2` (Filter Mode) by Android Zygote.


---

## Related Documentation

* [Main Project Documentation](README.md)
* [KernelSU Next Setup Guide](KERNELSU.md)
* [Installation and Flashing Guide](INSTALL.md)
* [Building from Source Guide](BUILD.md)
* [Kernel & Hardware Audit Registry](AUDIT_REGISTRY.md)
