# System Debloating and Optimization Guide (ADB)

This guide documents the system debloating framework for LineageOS 21.0 (Android 14) on the Xiaomi Redmi Note 5 Pro (`whyred`).

---

## Overview

Although LineageOS 21.0 is significantly cleaner than vendor stock firmware (MIUI/HyperOS), the default AOSP framework includes services, telemetry agents, regional authentication daemons, and hardware abstraction stubs that are inactive or redundant on `whyred` (such as NFC, which the hardware lacks).

System apps can be safely uninstalled for the primary user (`user 0`) over ADB without root privileges, partition remounting, or modifying the read-only `/system` or `/vendor` partitions.

### Key Benefits
* **RAM Optimization:** Releases background memory from persistent daemons and unused broadcast receivers.
* **CPU and Power Reduction:** Eliminates background wakeups, alarms, and periodic polling jobs from telemetry services.
* **Zero System Partition Risk:** Because packages are uninstalled using Android's user space package manager (`pm uninstall --user 0`), all changes are fully reversible at any time via `cmd package install-existing`.

---

## Automated Debloating Script (`debloat_whyred.sh`)

A modular, self-contained shell script is provided in the root of the repository: [`debloat_whyred.sh`](debloat_whyred.sh). It includes all **102 safe packages** documented below and executes in less than one second using package presence caching.

### Quick Usage

```bash
# 1. Debloat all 102 safe packages in one single step
./debloat_whyred.sh

# 2. Preview packages to be debloated without modifying the device (Dry-Run)
./debloat_whyred.sh --dry-run

# 3. Restore and re-install previously uninstalled packages
./debloat_whyred.sh --restore

# 4. List all registered packages grouped by section
./debloat_whyred.sh --list
```

### Modular Customization

The script organizes packages into 4 categorized bash arrays at the top of the file:
1. `TELEMETRY_AND_DAEMONS`: Background trackers, regional daemons (Soter, IFAA), unused hardware services (NFC).
2. `LINEAGEOS_MULTIMEDIA`: Stock media tools (Jelly, Eleven, Recorder, AudioFX, SetupWizard).
3. `BACKGROUND_AND_SYNC`: Cloud backup helpers, remote key provisioning, DSU, Health Connect.
4. `THEME_OVERLAYS`: Unused AOSP icon packs, shapes, and font overlays.

To exclude any package from being uninstalled, open [`debloat_whyred.sh`](debloat_whyred.sh) and comment out its line with `#`. To add new packages, append them directly to the appropriate array.

### Robust Package Handling
* Standard packages are uninstalled for `user 0` using `pm uninstall --user 0 <pkg>`.
* Packages restricted by Android framework policy (such as `org.lineageos.profiles`) automatically fall back to `pm disable-user --user 0 <pkg>`.
* The `--restore` flag invokes both `pm enable <pkg>` and `cmd package install-existing <pkg>`.

---

## Manual ADB Commands

If you prefer removing or restoring packages individually without the automated script:

### Uninstall via ADB
```bash
adb shell pm uninstall --user 0 <package_name>
```

### Disable via ADB (Restricted Packages)
```bash
adb shell pm disable-user --user 0 <package_name>
```

### Revert and Restore Uninstalled App
```bash
adb shell cmd package install-existing <package_name>
```

---

## Debloat Package Registry (`whyred`)

The following packages have been audited and verified safe for removal on Xiaomi Redmi Note 5 Pro (`whyred`) running LineageOS 21.0:

### 1. Telemetry, Tracking and Unused Daemons (35 Packages)

| Package Name | Description | Reason for Removal |
| :--- | :--- | :--- |
| `com.android.nfc` | AOSP NFC Service | Hardware absent on `whyred` (no NFC controller) |
| `org.lineageos.updater` | LineageOS OTA Updater | Inactive on unofficial builds; frees background polling |
| `org.lineageos.updater.auto_generated_rro_product__` | OTA Updater RRO Overlay | Associated overlay resource for LineageOS Updater |
| `com.tencent.soter.soterserver` | Tencent Soter Biometrics | WeChat biometric authentication daemon (China-specific) |
| `com.dsi.ant.server` | ANT+ Radio Service | ANT+ protocol daemon for sports sensors (unused) |
| `org.ifaa.aidl.manager` | IFAA Payment Manager | Alipay biometric authentication framework (unused) |
| `com.stevesoltys.seedvault` | Seedvault Backup | Local background backup agent |
| `org.calyxos.backup.contacts` | CalyxOS Contacts Backup | Seedvault contact backup provider |
| `com.android.adservices.api` | Privacy Sandbox / AdServices | Google telemetry and ad measurement API |
| `com.android.federatedcompute.services` | Federated Compute | Background machine-learning telemetry service |
| `com.android.ondevicepersonalization.services` | On-Device Personalization | Behavioral tracking and personalization telemetry |
| `com.android.bips` | Built-in Print Service | Local network printer discovery service |
| `com.android.printservice.recommendation` | Print Service Recommendation | Background network scanner for printer plugins |
| `com.android.stk` | SIM Application Toolkit | Carrier popup menus and interactive alerts |
| `com.caf.fmradio` | Qualcomm FM Radio | Analog FM tuner (unused without wired headphones) |
| `com.qualcomm.embms` | LTE Broadcast Service | Qualcomm eMBMS broadcast framework |
| `com.qti.dpmserviceapp` | Qualcomm DPM Service | Qualcomm Data Port Management daemon |
| `com.android.DeviceAsWebcam` | USB Webcam Mode | Virtual USB video class streaming service |
| `com.android.emergency` | Emergency Assistance | AOSP emergency contact and alert shortcut |
| `com.android.bookmarkprovider` | Browser Bookmark Provider | Legacy AOSP bookmark storage provider |
| `com.android.cts.ctsshim` | CTS Shim | Compatibility Test Suite test runner stub |
| `com.android.cts.priv.ctsshim` | CTS Privileged Shim | Compatibility Test Suite privileged test stub |
| `com.android.egg` | Android 14 Easter Egg | Mini-game asset included in system settings |
| `com.android.htmlviewer` | HTML Viewer | Basic HTML previewer fallback |
| `com.google.android.apps.googlecamera.fishfood` | Google Camera Dogfood | Internal testing stub for Google Camera |
| `com.android.dreams.basic` | Basic Screensaver | AOSP default screensaver component |
| `com.android.dreams.phototable` | Photo Table Screensaver | Interactive photo screensaver component |
| `com.android.wallpaper.livepicker` | Live Wallpaper Picker | Engine for animated live wallpaper backgrounds |
| `com.android.wallpaperbackup` | Wallpaper Backup Agent | Cloud sync helper for wallpaper images |
| `com.android.cellbroadcastreceiver` | Emergency Broadcasts | Cell broadcast emergency alert receiver |
| `com.android.cellbroadcastreceiver.module` | Emergency Broadcast Module | Mainline module for emergency cell broadcast alerts |
| `com.android.cellbroadcastservice` | Cell Broadcast Service | Background service managing cell alert states |
| `com.android.smspush` | WAP Push Manager | Legacy WAP push message receiver |
| `com.android.simappdialog` | SIM App Dialog | Carrier dialog display framework |
| `com.android.carrierdefaultapp` | Carrier Default App | Fallback carrier provisioning app |
| `com.android.pacprocessor` | Proxy Auto-Config | PAC file parsing daemon for corporate proxies |
| `com.android.proxyhandler` | Proxy Handler | HTTP/HTTPS proxy connection handler |
| `com.fingerprints.extension.service` | Fingerprint Extension | Legacy FPC fingerprint vendor extension |

### 2. LineageOS Multimedia and Utilities (8 Packages)

| Package Name | Description | Reason for Removal |
| :--- | :--- | :--- |
| `org.lineageos.jelly` | Jelly Web Browser | Lightweight browser (superseded by modern browsers) |
| `org.lineageos.eleven` | Eleven Music Player | Legacy local audio player |
| `org.lineageos.recorder` | Sound Recorder | LineageOS audio recording utility |
| `org.lineageos.audiofx` | AudioFX Equalizer | Built-in DSP equalizer (often replaced by Viper4Android) |
| `org.lineageos.backgrounds` | Lineage Wallpapers | Stock wallpaper asset bundle |
| `org.lineageos.profiles` | System Profiles | Automated sound/connection system profile switcher |
| `org.lineageos.setupwizard` | Setup Wizard | Initial device setup wizard (safe post-setup) |
| `org.lineageos.setupwizard.auto_generated_rro_product__` | Setup Wizard Overlay | Associated product overlay for setup wizard |

### 3. Background Sync and System Agents (21 Packages)

| Package Name | Description | Reason for Removal |
| :--- | :--- | :--- |
| `com.android.backupconfirm` | Backup Confirmation | Interactive prompt for desktop `adb backup` |
| `com.android.bluetoothmidiservice` | Bluetooth MIDI Service | MIDI synthesizer protocol over Bluetooth LE |
| `com.android.cameraextensions` | Camera OEM Extensions | Qualcomm vendor camera extension stub |
| `com.android.calllogbackup` | Call Log Backup | Cloud backup helper for call logs |
| `com.android.dynsystem` | Dynamic System Update (DSU) | GSI loader framework for secondary system booting |
| `com.android.health.connect.backuprestore` | Health Connect Backup | Backup provider for health data sync |
| `com.android.healthconnect.controller` | Health Connect Controller | Permissions interface for Health Connect framework |
| `com.android.localtransport` | Local Backup Transport | Loopback storage transport for ADB backup commands |
| `com.android.managedprovisioning` | Work Profile Provisioning | Enterprise MDM and managed profile provisioning |
| `com.android.ons` | Opportunistic Network Service | Multi-SIM carrier profile dynamic switching |
| `com.android.providers.settings.auto_generated_rro_product__` | Settings RRO Overlay | Product overlay for system settings |
| `com.android.providers.userdictionary` | User Dictionary Provider | Custom keyboard dictionary learning store |
| `com.android.rkpdapp` | Remote Key Provisioning | Keystore attestation remote provisioning daemon |
| `com.android.role.notes.enabled` | Notes Role Configuration | Default role assignment helper for notes apps |
| `com.android.safetycenter.resources` | Safety Center Resources | UI assets for Google Safety Center interface |
| `com.android.settings.intelligence` | Settings Search & Suggestions | Search indexer and dynamic suggestions for Settings |
| `com.android.sharedstoragebackup` | Shared Storage Backup | Backup provider for external shared storage |
| `com.android.systemui.accessibility.accessibilitymenu` | Accessibility Menu Shortcut | On-screen floating accessibility button |
| `com.android.systemui.plugin.globalactions.wallet` | Quick Wallet Access | Power menu Google Wallet card shortcut |
| `com.android.virtualmachine.res` | Microdroid VM Resources | Virtualization framework assets |

### 4. System and Theme Overlays (AOSP Theme Engine - 38 Overlays)

| Category | Packages | Reason for Removal |
| :--- | :--- | :--- |
| **Icon Packs (24)** | `com.android.theme.icon_pack.{circular, filled, kai, rounded, sam, victor}.{android, launcher, settings, systemui}` | Unused AOSP icon theme variants |
| **Icon Shapes (7)** | `com.android.theme.icon.{pebble, roundedrect, square, squircle, taperedrect, teardrop, vessel}` | Unused adaptive icon mask shapes |
| **Fonts (3)** | `org.lineageos.overlay.font.{lato, rubik}`, `com.android.theme.font.notoserifsource` | Unused secondary font overlays |
| **System Overlays (2)** | `android.auto_generated_rro_product__`, `android.auto_generated_rro_vendor__` | Redundant generated resource overlays |

---

## Critical Apps Kept Intact (DO NOT REMOVE)

The following core applications must remain installed unless explicit replacements (such as GCam, Gboard, or Google Contacts) are installed beforehand:

| Package Name | Application Name | Purpose / Function |
| :--- | :--- | :--- |
| `org.lineageos.aperture` | Aperture Camera | Default camera application |
| `com.android.inputmethod.latin` | AOSP Keyboard | Primary on-screen keyboard (IME) |
| `com.android.dialer` | Phone / Dialer | Call management and in-call UI |
| `com.android.messaging` | Messages | SMS/MMS text messaging client |
| `com.android.contacts` | Contacts | Local contact list and account manager |
| `com.android.calculator2` | Calculator | Basic mathematical calculation utility |
| `com.android.deskclock` | Clock / Alarms | System alarms, timer, and stopwatch |
| `org.lineageos.glimpse` / `com.android.gallery3d` | Gallery | Local photo and video viewing |
| `org.lineageos.etar` | Etar Calendar | Local calendar and scheduling interface |

---

## Related Documentation

* [Main Project Documentation](README.md)
* [Installation and Flashing Guide](INSTALL.md)
* [KernelSU Next & SuSFS Setup Guide](KERNELSU.md)
* [Building from Source Guide](BUILD.md)
* [Kernel & Hardware Audit Registry](AUDIT_REGISTRY.md)
