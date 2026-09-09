# Hardware Audit & Test Registry: Xiaomi Redmi Note 5 (whyred)

This document serves as the official, chronological, and comprehensive registry of all hardware validation gates, subsystem diagnostic audits, defect analyses, and applied solutions conducted on the Xiaomi Redmi Note 5 (`whyred`) platform under LineageOS 21.0 (Android 14 / Linux Kernel 4.19).

In accordance with `AGENTS.md` Section 13, this registry must be continuously maintained and updated after every testing session or validation gate.

---

## Subsystem Audit Summary Matrix

| Gate / Phase | Subsystem & Scope | Status / Verdict | Defects Identified | Solution Summary | Commits & Trees |
| :--- | :--- | :---: | :--- | :--- | :--- |
| **Gate THRM** | Thermal Engine, CPUFreq Governors | `[FIXED]` | Big cluster CPU4..7 pinned to `performance` | Set `schedutil` governor on early-init | `072ce85` (`sdm660-common`) |
| **Gate MEM** | zRAM, Page-Cluster, Memory Reclamation | `[FIXED]` | `page-cluster=3` causing 32KB read latency spikes | Set `vm.page-cluster = 0` for single-page swapin | `9d56781` (`sdm660-common`) |
| **Fases E-H** | Hexagon Modem, QRTR, DIAG, GLINK, SSR | `[FIXED]` | Hexagon modem crash on suspend (`Task starvation: diag`) | Create QRTR diag sockets in kernel context (`sock_create_kern`) | `0f3ecebf7e31` / `39c283687293` (`kernel`) |
| **Fase I** | Sensors, SensorHub, ADSP, SSC | `[PASS]` | None | Nominal; all physical sensors streaming valid FIFO data | 0 changes |
| **Fase J / J-R** | Camera, ISP, Camera HAL3, Dual Bokeh | `[FIXED]` | Front camera freeze with Sunny Chromatix; 32-bit libs missing | Route Sunny Chromatix to Ofilm; add 32-bit libpng/libpiex | `b71d058` (`vendor`), `ac728cf`, `735a8d0` (`device`) |
| **Fase K** | Display, MDSS FBDEV, Adreno 509, SurfaceFlinger | `[PASS]` | None | Nominal 60Hz composition, zero GPU faults or KGSL timeouts | 0 changes |
| **Fase L / L-R** | Audio, ASoC, PM660L Codec, TAS2557 Amp | `[PASS]` | Benign unused AFE clock errors | Benign vendor tech debt; primary audio routing fully nominal | 0 changes |
| **Fase M / M-R** | Power, Battery, SMB2, FG Gen3, JEITA | `[PASS]` | Suspend `-EBUSY` when USB connected | Characterized as expected USB host polling under active ADB | `7840eba87cb9` (`kernel`) |
| **Fase N / N-R1** | Biometrics, Fingerprint HAL, Keymaster, TEE | `[FIXED]` | ABI symbol mismatch in `com.fingerprints.extension@1.0.so` | Rebuilt vendor compatibility bridge / ABI shim | `026e3be` (`sdm660-common`), `2b7afc5` (`device`) |
| **Fase O** | Wi-Fi (`qcacld-3.0`), SoftAP, ACS, Concurrency | `[FIXED]` | 1) SoftAP failed with 5GHz STA; 2) Kernel buffer underflow | 1) Enable MCC in ini; 2) Add ACS channel bounds check | `503e134` (`sdm660-common`), `2fb1c8a829be` / `54f411d70954` (`kernel`) |
| **Gate SEC/BUILD**| Developer Options, System Properties, SELinux | `[FIXED]` | Settings crash on Developer Options launch | Resolved by canonical `user` reflash (`ro.debuggable=0`) | 0 source changes |
| **Gate REL/BUILD**| Release Packaging, Non-A/B Zip Generation | `[FIXED]` | Symlinks broken in non-A/B zip; test-keys display | Add `-y` flag in releasetools; default to release-keys | `4f5bdcdc99`, `d80b1cf7de` (`build/make`) |
| **Gate USB** | USB DWC3, Gadget Modes, Host OTG, Off-Mode Chg | `[PASS]` | None | All gadget functions, OTG host enumeration, 5x plug & 3x OTG cycles validated | 0 changes |
| **Gate RIL** | Telephony, SIM, Mobile Data, Calls, IMS, VoLTE | `[PASS]` | None | SIM detection, LTE data (HTTP 200 OK), *611 call, SMS, IMS IPv6 validated | 0 changes |
| **Gate BT/GNSS** | Bluetooth WCN3990 (UART/BLE), GNSS Engine/NMEA | `[PASS]` / `[NOT TESTED]` | Physical GNSS fix not tested (indoor workstation) | BT: PASS (BLE discovery over air, 3x cycles, A2DP proxy, suspend); GNSS: Engine/NMEA PASS, Sky Fix NOT TESTED | 0 changes |
| **Gate CROSS/REG** | Cross-Subsystem Concurrency, Stress & Global Regression | `[PASS]` | None | WLAN+BT coex, Camera+Audio+Sensors concurrency, 4-radio deep sleep, Fingerprint HAL, 0 SSR/panics | 0 changes |
| **Fase P4 Baseline**| Stock Kernel Physical Benchmark Suite (M01-M10) | `[PASS]` | None (nominal baseline) | 10 dimensions executed, raw series recorded and JSON archived | `54f411d70954` (`kernel`) |
| **Fase P3.2.5** | Official San-Kernel Revenant R1.1.108 Boot Gate | `[FAIL]` | Official binary release hangs at splash ("Redmi") | Falsified rebuild hypothesis; confirmed official release non-bootable on device; rollback to stock verified | 0 changes |


---

## Detailed Subsystem Validation Records

### 1. Thermal Subsystem & CPUFreq Scaling (Gate THRM)
* **Scope**: CPU frequency governor configuration, core clustering (Kryo 260 Silver CPU0..3 and Kryo 260 Gold CPU4..7), and thermal throttling limits.
* **Test Procedures**:
  - Telemetry polling from `/sys/devices/system/cpu/cpufreq/policy*`.
  - Governor behavior verification under synthetic CPU load and idle states.
  - Verification of thermal mitigation thresholds in `thermal-engine`.
* **Defect Identified**:
  - Big cluster cores (CPU4..7) remained permanently locked at max clock in `performance` governor even during system idle, resulting in elevated battery drain and continuous thermal dissipation.
  - Root cause was traced to an overriding instruction in `init.qcom.power.rc`.
* **Applied Solution**:
  - Configured `schedutil` governor for CPU4..7 during `early-init` / `post_boot` in `device/xiaomi/sdm660-common/rootdir/etc/init.qcom.power.rc`.
* **Commit**: `072ce85` (`device/xiaomi/sdm660-common`).
* **Verdict**: `[FIXED]`. All 8 cores scale dynamically down to 633 MHz at idle with responsive frequency boost under user interactions.

---

### 2. Memory, Swap & zRAM Subsystem (Gate MEM)
* **Scope**: zRAM swap configuration, page clustering, compression stream allocation, and low-memory killer daemon (LMKD) responsiveness.
* **Test Procedures**:
  - Sequential memory allocation stress using synthetic workloads.
  - Swap utilization tracking in `/proc/meminfo` and `/proc/vmstat`.
  - Kernel memory stall measurement via Pressure Stall Information (PSI).
* **Defect Identified**:
  - `/proc/sys/vm/page-cluster` was configured to `3`, forcing the kernel to perform an 8-page (32 KB) readahead on every swapin from zRAM. Because zRAM is RAM-backed compressed storage rather than a rotating or block-buffered disk, multiblock readahead introduced significant decompression overhead, cache pollution, and latency spikes.
* **Applied Solution**:
  - Set `vm.page-cluster = 0` in `device/xiaomi/sdm660-common/rootdir/etc/init.target.rc` to enforce single-page transfers.
* **Commit**: `9d56781` (`device/xiaomi/sdm660-common`).
* **Verdict**: `[FIXED]`. Significantly reduced page-fault decompression latency and memory stalls under high multitasking load.

---

### 3. Hexagon Modem, DIAG, QRTR & Subsystem Restart (Fases E-H)
* **Scope**: Qualcomm Hexagon modem (MSS / MSS0), GLINK interconnect, Qualcomm Real-Time Router (QRTR), DIAG framework, and deep sleep suspend/resume stability.
* **Test Procedures**:
  - Device suspend/resume cycles with active cellular registration and Wi-Fi state changes.
  - Telemetry capture from Hexagon shared memory region 421 (`SMEM_SSR_REASON_MSS0`).
  - Kernel panic and watchdog bark analysis across consecutive sleep cycles.
* **Defect Identified**:
  - The device suffered a kernel watchdog bark and immediate reboot during suspend: `Task starvation: diag`.
  - Physical inspection of SMEM 421 confirmed the Hexagon modem halted execution because its diagnostic transport thread starved.
  - Root cause: The kernel DIAG driver (`diagfwd_socket.c`) utilized `sock_create()` from kernel worker threads. Under SELinux and user-namespace restrictions in Android 14, socket creation failed or lacked necessary credentials, causing the DIAG worker to block indefinitely.
* **Applied Solution**:
  - Modified socket instantiation in `kernel/xiaomi/sdm660/drivers/char/diag/diagfwd_socket.c` to explicitly call `sock_create_kern(&init_net, ...)` to guarantee kernel-context credentials.
  - Synchronized patch across both `lineage-21` (stock) and `lineage-21-ksu` branches to preserve strict parity.
* **Commits**: `0f3ecebf7e31` / `39c283687293` (`kernel/xiaomi/sdm660`).
* **Verdict**: `[FIXED]`. Completely eliminated modem task starvation, zero SSR events during suspend/resume, and stable cellular standby.

---

### 4. Sensors & Snapdragon Sensor Core (Fase I)
* **Scope**: Qualcomm Snapdragon Sensor Core (SSC) running on ADSP, HIDL `android.hardware.sensors@1.0`, and physical motion/environmental sensors.
* **Test Procedures**:
  - Enumeration check of all onboard sensors (Bosch/ST Accelerometer, Gyroscope, Magnetometer, Lite-On/AMS Proximity & Ambient Light, Step Detector).
  - Event rate and FIFO stability verification under active sensor listening.
  - Sensor suspend and wake-up event behavior during screen transitions.
* **Findings**:
  - All physical sensors enumerated accurately and reported real-time calibrated values without IPC dropouts or FIFO buffer overruns.
* **Verdict**: `[PASS]`. Subsystem nominal; zero modifications required.

---

### 5. Camera & Imaging Subsystem (Fase J / J-R)
* **Scope**: Qualcomm Camera HAL3 (`android.hardware.camera.provider@2.4`), ISP hardware pipes, dual rear cameras (Samsung s5k2l7 + Samsung s5k5e8), front camera (Omnivision ov13855 / ov5675), and Android 14 BLAST SurfaceView integration.
* **Test Procedures**:
  - Photo capture and 1080p/4K 30fps video recording on front and rear cameras via Aperture app.
  - Dual-camera portrait/bokeh depth map computation.
  - Flashlight illumination and torch mode toggling.
  - Gralloc buffer mapping under Android 14.
* **Defects Identified & Solutions**:
  1. *Front Camera Freeze*: Loading Sunny Chromatix for the `ov13855` front sensor caused camera pipeline timeouts. Solved in `vendor/xiaomi/whyred` by routing Sunny Chromatix configuration to Ofilm (`b71d058`).
  2. *Missing HAL Dependencies*: Camera HAL failed on clean builds due to missing 32-bit `libpng` and `libpiex` dependencies. Fixed in `device/xiaomi/whyred` (`735a8d0`).
  3. *Proprietary Files Tracking*: Included `ov13855` ofilm chromatix libraries in vendor extraction specs (`ac728cf`).
  4. *Gralloc Buffer Offset*: Adjusted `private_handle_t` buffer layout in camera wrapper for Android 14 compatibility (`f5e69fd`).
  5. *JPEG Encoding Stability*: Enforced routing to stable Qualcomm hardware OMX JPEG encoder (`4e634d9`).
* **Verdict**: `[FIXED] / [PASS]`. Complete camera functionality fully operational, responsive focus, and zero image pipeline crashes.

---

### 6. Display & Graphics Processing (Fase K)
* **Scope**: Qualcomm Mobile Display Subsystem (MDSS FBDEV), Synaptics TD4310 panel driver, Adreno 509 GPU, SurfaceFlinger, and Hardware Composer (HWC 2.0).
* **Test Procedures**:
  - Hardware VSync synchronization audit (`dumpsys SurfaceFlinger --latency`).
  - OpenGL ES 3.2 and Vulkan rendering pipelines.
  - Display power state toggles (`BLANK` / `UNBLANK`) and brightness adjustments.
* **Findings**:
  - Zero dropped frames at sustained 60 FPS, no GPU fence timeouts, clean kernel frame buffer lifecycle.
* **Verdict**: `[PASS]`. Subsystem nominal; zero modifications required.

---

### 7. Audio & Sound Subsystem (Fase L / L-R)
* **Scope**: Qualcomm ASoC audio architecture, PM660L internal codec, Texas Instruments TAS2557 smart amplifier, Audio HAL 7.1, AudioFlinger, and wired headset detection.
* **Test Procedures**:
  - Stereo loudspeaker playback, earpiece audio during voice calls, and 3.5mm headphone jack insertion/removal detection.
  - Microphone routing across primary, secondary, and noise-cancelling mics.
  - Kernel AFE trace audit and sound trigger AIDL/HIDL fallback verification.
* **Findings**:
  - Identified benign vendor trace messages (`q6afe.c: afe_set_source_clk fail -22` on unused audio endpoints and Sound Trigger HIDL 2.1 fallback). These do not affect active streams. Primary playback, amplification, and recording are fully stable.
* **Verdict**: `[PASS]`. Subsystem nominal; zero modifications required.

---

### 8. Power, Charging & Battery Management (Fase M / M-R)
* **Scope**: Qualcomm PM660 SMB2 charger controller, Fuel Gauge Gen3 (`fg-gen3`), JEITA state machine, step-charging limits, and battery capacity scaling.
* **Test Procedures**:
  - Evaluation of JEITA voltage and current thresholds across thermal steps.
  - Real-time battery status, current drain, and capacity reporting in `/sys/class/power_supply/battery`.
  - Suspend behavior analysis under USB connected vs disconnected states.
* **Defects Identified & Solutions**:
  1. *Capacity Reporting*: Fixed `charge_full_design` scaling to microampere-hours and added fallback capacity computation in kernel battery driver (`7840eba87cb9`).
  2. *USB Suspend Behavior*: Documented that the Synopsys DWC3 controller returns `-16` (`-EBUSY`) in `platform_pm_suspend` when an active USB host connection (ADB) is maintained. The evidence indicates this corresponds to the expected behavior of the DWC3 controller under active host configuration rather than a driver failure.
* **Verdict**: `[PASS CARACTERIZADO]`. Power management, JEITA protection curves, and fuel gauge reporting validated.

---

### 9. Biometrics, Cryptography & Security (Fase N / N-R1)
* **Scope**: Goodix `gf3208` and FPC1020 fingerprint sensors, TrustZone QSEECOM client, Keymaster 3.0/4.0 HAL, Gatekeeper, and File-Based Encryption (FBE) under Android 14.
* **Test Procedures**:
  - Fingerprint HAL initialization (`android.hardware.biometrics.fingerprint@2.3`).
  - Hardware finger enrollment, recognition, and false-rejection testing.
  - Keystore key generation, signature verification, and user authentication gating.
* **Defect Identified**:
  - The proprietary Xiaomi extension library `com.fingerprints.extension@1.0.so` contained an ABI incompatibility and missing symbol definitions in Android 14 64-bit userspace, preventing the biometric extension service from loading.
* **Applied Solution**:
  - Implemented an ABI compatibility shim in `device/xiaomi/sdm660-common` and cleaned up duplicate vendor build entries.
* **Commits**: `026e3be` (`device/xiaomi/sdm660-common`), `2b7afc5` (`device/xiaomi/whyred`), `8ea9e02` (`vendor/xiaomi/whyred`).
* **Verdict**: `[FIXED]`. Fingerprint enrollment and unlock operational; FBE storage encryption verified.

---

### 10. Connectivity: Wi-Fi, SoftAP & Channel Concurrency (Fase O)
* **Scope**: Qualcomm `qcacld-3.0` WLAN driver, WCN3990 wireless radio, Station (STA) mode, SoftAP (Wi-Fi Hotspot), Automatic Channel Selection (ACS), and Multi-Channel Concurrency (MCC / SCC).
* **Test Procedures**:
  - STA association to 2.4 GHz and 5 GHz access points.
  - SoftAP broadcast on 2.4 GHz and 5 GHz with ACS enabled.
  - Simultaneous dual-band concurrency (STA connected on 5 GHz Ch 149 + SoftAP active on 2.4 GHz).
* **Defects Identified & Solutions**:
  1. *SoftAP Concurrency Failure*: Hotspot failed to activate on 2.4 GHz when the phone was associated to a 5 GHz Wi-Fi network because `gWlanMccEnable=0` was set in the configuration. Resolved by enabling MCC in `device/xiaomi/sdm660-common/wifi/WCNSS_qcom_cfg.ini` (`503e134`).
  2. *Driver Buffer Underflow*: During ACS channel scanning, if the candidate channel list was empty, the `qcacld-3.0` driver evaluated `ch_list[acs_channel_count - 1]` with count `0`, triggering an array index underflow (`ch_list[-1]`) and memory corruption. Resolved by introducing explicit bounds checks in `kernel/xiaomi/sdm660/drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_hostapd.c` (`2fb1c8a829be` on KSU, `54f411d70954` on stock).
* **Verdict**: `[FIXED] / [PASS]`. Stable concurrent STA + SoftAP operation with zero driver faults or kernel memory violations.

---

### 11. System Properties & Developer Settings Crash (Gate SEC/BUILD)
* **Scope**: System build type (`user` vs `userdebug`), SELinux Enforcing rules on `com.android.settings`, and `SettingsLib` Logpersist controller.
* **Test Procedures**:
  - Automated loop of 10 consecutive launches of Developer Options via `am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS`.
  - SELinux AVC audit for `logpersistd_logging_prop` and `system_app`.
  - Crash buffer inspection via `logcat -b crash`.
* **Defect Identified**:
  - Launching Developer Options crashed `com.android.settings` with a fatal SELinux denial.
  - Root cause: An ad-hoc modified `/system/build.prop` on the test device had forced `ro.debuggable=1` and `ro.adb.secure=0` over a `user` build (`ro.build.type=user`). `SettingsLib` inspected `ro.debuggable=1` and instantiated `LogPersistPreferenceController`, which attempted to write `logpersistd.enable`. In canonical AOSP `user` builds, `set_prop(system_app, logpersistd_logging_prop)` is deliberately omitted, resulting in an Enforcing denial and app crash.
* **Applied Solution**:
  - Flashed a clean, canonical `user` package built by this tree (`ro.debuggable=0`, `ro.adb.secure=1`, `ro.secure=1`) without local modifications.
  - Confirmed that canonical `user` builds disable `LogPersistPreferenceController`, eliminating the write attempt entirely. Zero source code or sepolicy modifications were required.
* **Verdict**: `[FIXED] / [PASS]`. 10/10 launches succeeded with focus on `Settings$DevelopmentSettingsActivity`, 0 crashes, 0 AVCs.

---

### 12. Build System & Packaging Integrity (Gate REL/BUILD)
* **Scope**: Target packaging rules, non-A/B OTA zip generation, filesystem symlink preservation, and custom release signing certificates.
* **Test Procedures**:
  - Verification of release packages generated via `build/make/tools/releasetools/ota_from_target_files`.
  - Inspection of symlink attributes in generated flashable zips.
  - Verification of system property `ro.build.tags` under custom certificate presence.
* **Defects Identified & Solutions**:
  1. *Broken Symlinks in Non-A/B Zips*: In non-A/B target packages, standard zip packaging stripped symlinks. Resolved in `build/make` by adding `-y` to zip command invocations in releasetools (`4f5bdcdc99`).
  2. *Build Tags Default*: System properties defaulted to `test-keys` even when custom signing keys were configured. Resolved by checking certificate availability and defaulting to `release-keys` (`d80b1cf7de`).
* **Verdict**: `[FIXED]`. Deterministic, cryptographically signed, and flashable non-A/B release packages.

---

### 13. USB, OTG & Synopsys DWC3 Subsystem (Gate USB)
* **Scope**: Synopsys DWC3 USB controller (`a800000.dwc3`), USB ConfigFS gadget functions, host mode OTG (`dr_mode = "otg"`), VBUS boost delivery, off-mode charging architecture, and suspend/resume lifecycle.
* **Test Procedures**:
  - Gadget function switching via `svc usb setFunctions` across ADB, MTP+ADB, PTP+ADB, MIDI+ADB, and RNDIS/Tethering, validating descriptors on host xHCI controller.
  - Physical cable disconnection and reconnection stress test (5 complete cycles) auditing UDC unbind/bind and `android_usb` uevents.
  - Physical OTG host mode validation (3 complete connect/disconnect cycles) using a Micro-USB OTG adapter with an external USB peripheral (Compx VXE Mouse Dongle `0x3554:0xf58e`).
  - Battery service charging state validation under VBUS detection (5V / 500mA SDP rail).
  - Suspend and resume verification under USB connected vs disconnected states.
  - Reboot test with active USB connection (`adb reboot`) verifying clean re-enumeration into `boot_completed=1`.
  - Source and runtime audit of off-mode charging (`vendor.charger`).
* **Findings**:
  - All USB gadget compositions enumerated with expected VID:PIDs (`18d1:4ee7` ADB, `18d1:4ee2` MTP+ADB, `18d1:4ee6` PTP+ADB, `18d1:4ee9` MIDI+ADB, `05c6:9024` RNDIS+ADB).
  - Physical OTG mode enabled 5V VBUS boost, enumerated the peripheral under `/dev/bus/usb/001/002` across all 3 cycles (`host_manager.num_connects = 6`), and switched cleanly back to peripheral mode when connected to PC host.
  - Off-mode charging is fully implemented in tree via `vendor.charger` (`android.hardware.health-service.qti --charger`) under `class charger`.
  - Phase M correlation: The evidence obtained indicates that the `-EBUSY` (`-16`) return in `platform_pm_suspend` observed during Phase M corresponds to the expected behavior of the DWC3 controller when an active USB configuration is maintained with an active host, and it did not manifest as a functional defect during this audit.
  - Zero crashes in `logcat -b crash`, zero controller timeouts or starvation events.
* **Verdict**: `[PASS]`. Subsystem fully validated; zero modifications required (0 code changes, 0 commits).

---

### 14. Telephony, RIL, Cellular Data & IMS Subsystem (Gate RIL)
* **Scope**: Qualcomm RIL (`rild`), Hexagon Modem (MSS), SIM detection, cellular network registration, 4G/LTE mobile data (`rmnet_data*`), voice calls, SMS dispatch, Wi-Fi ↔ LTE handoffs, Airplane Mode transitions, and IMS/VoLTE bearer establishment.
* **Test Procedures**:
  - SIM status verification (`gsm.sim.state = LOADED`).
  - Network attachment audit on Movistar LTE (MCC=722, MNC=07, Band 28 / Band 4 / Band 7, PCI 288/483, TAC 45118).
  - Outgoing voice call test to carrier service `*611` via `Intent.ACTION_CALL`, auditing Telecom state machine, `ActiveEarpieceRoute`, off-hook state (`mCallState=2`), and clean call teardown (`KEYCODE_ENDCALL`).
  - SMS dispatch test via `com.android.internal.telephony.ISms` (`sendTextForSubscriber()`) targeting carrier shortcode `444`, confirming zero RIL dispatcher dropouts or binder exceptions.
  - Cellular data traffic validation with Wi-Fi disabled (`svc wifi disable`), auditing carrier DNS (`186.130.128.249`) and live HTTP/1.1 200 OK payload exchange with Google over `rmnet_data1`.
  - Wi-Fi ↔ LTE handoff audit, verifying seamless route transition without socket drops.
  - Airplane Mode toggle verification, auditing complete radio power-down and instantaneous (< 3s) LTE carrier reacquisition upon restoration.
  - Deep sleep suspend/resume test (5s screen off) with active LTE and background mobile data, inspecting Hexagon SSR status and dmesg for watchdog barks.
* **Findings**:
  - Outgoing voice call successfully transitioned through `SIM_CALL`, `MODE_IN_CALL`, `ActiveEarpieceRoute`, and dialed `*611` without audio glitches or drops.
  - SMS framework (`isms`) is fully operational; `sendTextForSubscriber` executed cleanly.
  - Mobile data (`rmnet_data1`) passed real HTTPS/TCP traffic (HTTP 200 OK).
  - IMS bearer (`rmnet_data3`) established with dedicated IPv6 addressing and carrier PCSCF assignment; celda reports `mVopsSupport = 2` (Voice over PS supported).
  - Correlación Fases E-H: Zero modem crashes or task starvation observed during suspend/resume with active mobile data; corroborates the `sock_create_kern` QRTR patch across the tested scenarios.
  - Zero crashes across `logcat -b crash`, zero RIL resets or IPC timeouts.
* **Verdict**: `[PASS]`. Subsystem fully validated; zero modifications required (0 code changes, 0 commits).

---

### 15. Bluetooth (WCN3990) & GNSS / Location Subsystem (Gate BT/GNSS)
* **Scope**: Qualcomm WCN3990 Bluetooth UART interface (`/dev/ttyHS0`), Bluetooth stack (Fluoride / libbt-vendor), power cycling (enable/disable), BLE scanning and advertisement reception, classic discovery, A2DP proxy and offload capabilities, suspend/resume with active BT, and Qualcomm LocAPI / QMI GNSS engine (`MPSS.AT.3.1-00777-SDM660_GEN_PACK-1.336736.1.337834.1`), NMEA streams, satellite visibility, constellation detection, and physical fix acquisition.
* **Test Procedures**:
  - Repeated Bluetooth enable/disable stress test (3 complete cycles), auditing framework state transitions and HCI daemon lifecycle.
  - WCN3990 transport audit: verified `/dev/ttyHS0` opening at 2400 bps, stepping to 115200 bps with hardware flow control, and switching to high-speed 3.2 Mbps (`3200000 bps`) with In-Band Sleep (IBS) clock gating.
  - Audio offloading capability audit: verified SBC, AAC, LDAC, APTX, and APTX_HD capability registration with `IBluetoothAudioProvidersFactory`.
  - Over-the-air BLE scan test via `BluetoothLeScanner` (`ScanCallback`) in live 2.4 GHz RF environment.
  - Classic device discovery via `BluetoothAdapter.startDiscovery()`.
  - A2DP profile proxy service verification via `BluetoothProfile.ServiceListener`.
  - Suspend/resume stress test (5s screen off) with active Bluetooth radio, auditing UART clock voting and kernel watchdog state.
  - GNSS engine initialization and NMEA sentence stream parsing via `OnNmeaMessageListener` and `LocationManager.GPS_PROVIDER` (45s continuous capture).
  - GNSS constellation and satellite status audit via `GnssStatus.Callback`.
* **Findings**:
  - Bluetooth 3x enable/disable transitions completed cleanly with zero timeouts or process crashes.
  - BLE scanner captured live physical broadcasts over the air from nearby devices, including `64:82:14:47:3F:4A` ("onn. Full HD Streaming Device", RSSI -66 dBm), `C4:30:18:D4:6A:68` ("LG RN5(68)", RSSI -91 dBm), and BLE beacons (`43:56:90:A2:00:01`, `28:07:08:F6:C6:71`).
  - Classic discovery initiated normally; no BR/EDR inquiry responses received (nearby devices operating exclusively in BLE advertising mode).
  - A2DP profile proxy registered and connected cleanly (0 bonded devices in test environment).
  - Bluetooth radio preserved active state after system deep sleep; zero UART drops or IBS desynchronization.
  - GNSS engine started immediately (`[GNSS] Engine started`), receiving 572 NMEA sentences across 45 seconds (`$GPGSV`, `$GLGSV`, `$GPGSA`, `$GPVTG`, `$GPDTM`).
  - Constellations observed: Strictly `GPS` and `GLONASS` (27 visible satellites in ephemeris model: 16 GPS, 11 GLONASS). Galileo and BeiDou were NOT OBSERVED (not reported by modem hardware/firmware).
  - Physical Satellite Fix: 0 location fixes acquired (all satellite C/N0 levels measured 0.0 dB-Hz) due to physical indoor workstation placement without direct line-of-sight to the sky.
  - Zero modem crashes, zero Hexagon SSR events, zero QMI errors, zero kernel panics.
* **Verdict**:
  - **Bluetooth**: `[PASS]` (Hardware, UART transport, BLE RF reception, and power management validated).
  - **GNSS Engine & NMEA Stack**: `[PASS]` (Qualcomm LocAPI, NMEA sentences, satellite almanac parsing, and engine lifecycle validated).
  - **GNSS Physical Sky Fix & TTFF**: `[NOT TESTED]` (Physical indoor test constraint; open sky required for satellite lock).
  - Zero code, kernel, device tree, or sepolicy changes required (0 changes).

---

### 16. Cross-Subsystem Concurrency & Global Regression Gate (Gate CROSS/REG)
* **Scope**: Simultaneous multi-subsystem interaction and cross-talk stress testing across applied fixes: WCN3990 WLAN/Bluetooth coexistence, Camera HAL3 + ADSP sensor hub + Audio HAL concurrency, deep sleep suspend/resume under multi-radio active state (LTE + Wi-Fi + Bluetooth + GNSS), Fingerprint HAL/Keymaster TEE bridge integrity, and kernel stability (SSR, watchdog, panic checks).
* **Test Procedures**:
  - WLAN + Bluetooth RF coexistence stress: executed live HTTP/1.1 200 OK network traffic over `wlan0` while Bluetooth concurrently performed continuous BLE advertisement scanning in the 2.4 GHz ISM band.
  - Multimedia & Sensor Hub concurrency: executed concurrent sensor event streaming (BMI120 Accelerometer, BMI120 Gyroscope, AK09918 Magnetometer, LTR578 ALS/PS, Rotation Vector, Step Counter) via ADSP SSC, PCM 440Hz sine wave audio playback via PM660L / TAS2557 smart amp, and hardware SOF frame captures on Camera 0 (Rear IMX486, 33 frames) and Camera 1 (Front OV13855, 83 frames @ 30.17 FPS, 2.16 ms jitter).
  - Multi-Radio deep sleep stress: enabled all 4 radios simultaneously (LTE cellular data on `rmnet_data1`, Wi-Fi on `wlan0`, Bluetooth on `wcn3990`, GNSS location listener on `LocationManager.GPS_PROVIDER`), initiated 10 seconds of screen-off deep sleep, and audited system wake-up.
  - Biometric HAL bridge verification: audited `dumpsys fingerprint` (`Fingerprint21` provider) and `com.fingerprints.extension@1.0.so` bridge shim state.
  - Kernel telemetry and crash audit: audited dmesg for Hexagon SSR events, QRTR socket leaks, DWC3 USB suspend `-EBUSY`, and `logcat -b crash` for process exceptions.
* **Findings**:
  - WLAN + Bluetooth coexistence: 5/5 HTTP 200 OK queries completed successfully over `wlan0` while 10 BLE broadcasts were captured over the air during the test interval.
  - Sensor Hub + Audio + Camera HAL3: Subsystems operated concurrently within the tested execution paths; no buffer errors, starvation events, or DSP crashes were observed. Rear camera captured frames cleanly and front camera maintained steady 30.17 FPS with 2.16 ms jitter during active sensor streaming.
  - Multi-Radio Deep Sleep: System resumed cleanly after 10s deep sleep with all 4 radios active; no Hexagon modem starvation events, QRTR crashes, watchdog barks, or USB bus errors were observed during the tested suspend-resume cycle.
  - Biometric Service: `Fingerprint21` service responsive and operational; HAL deaths since boot: 0.
  - System Integrity: Uptime 30+ min, CPU idle > 740%, thermal zones nominal (29-37 C), zero kernel panics, zero softlockups, zero SSR restarts, and zero unhandled process crashes across the executed matrix.
* **Verdict**: `[PASS]`. Global cross-subsystem regression test completed with nominal results across the evaluated matrix (0 code changes, 0 commits).

---

### 17. Stock Baseline Physical Comparative Benchmark Suite (Fase P4 Baseline)
* **Scope**: Comprehensive physical hardware benchmark across 10 evaluation dimensions (M01 to M10) on canonical stock kernel (`lineage-21`, commit `54f411d709549ab3746b9cf14e70852beeb3ba17`).
* **Test Procedures & Conditions**:
  - Device: Redmi Note 5 (`whyred` / `df286add`), battery 99% (4391 mV), initial SoC temp 25.0 C, SELinux Enforcing, KSU/SUSFS absent.
  - Raw time series and structured outputs archived in scratch:
    - Raw log: `scratch/benchmark_results/baseline_stock_raw.log` (113 KB).
    - Summary JSON: `scratch/benchmark_results/baseline_stock_summary.json` (12.8 KB).
  - Executed dimensions:
    - **M01**: CPU Single-Core (199.81 Mops/s), Multi-Core 8-thread (1075.03 Mops/s), Sustained 60s load (5.4% thermal degradation, 35.8 C -> 58.0 C).
    - **M02**: Scheduler & Context Switch Latency via `perf bench sched pipe` (16.99 us/op, 58,843 ops/s).
    - **M03**: IPC Throughput via 64KB unbuffered UNIX socket transfer (1780.20 MB/s).
    - **M04**: Cache & Memory Hierarchy bandwidth (L1 4.54 GB/s, L2 3.01 GB/s, L3 2.11 GB/s, DRAM 0.99 GB/s). Pointer chase characterized as non-conclusive for DRAM latency.
    - **M05**: Flash Storage I/O on `userdata` ext4 (Buffered write 191.07 MB/s, Sync write 76.16 MB/s, Direct read 1118.52 MB/s).
    - **M06**: Kernel Network Stack loopback TCP throughput (5.09 Gbps, 0 TCP retransmissions across 10s).
    - **M07**: Graphics & Display Composition (SurfaceFlinger 60.00 FPS nominal, 0 dropped frames).
    - **M08 / M10**: Power Consumption & Efficiency (Resting 4391 mV -> 4364 mV, mean loaded 4.141 V, Efficiency Index: 18,622,026 Mops/V).
    - **M09**: Deep Sleep Wakefulness state (`mWakefulness=Asleep`, `mHoldingWakeLockSuspendBlocker=false`).
* **Verdict**: `[PASS]`. Baseline reference dataset fully established, characterized, and locked.

---

### 18. Official Release San-Kernel Revenant R1.1.108 Physical Boot Gate (Fase P3.2.5)
* **Scope**: Physical bootability validation of the official, pristine `Image.xz` + `kernel.dtb` binary release from `San-Kernel-Revenant-R1.1.108-Whyred.zip` packaged with baseline stock ramdisk and canonical header v0.
* **Pre-Flash Audit**:
  - Official `Image.xz`: SHA256 `0eae553cb486774563cf1d9b9b483838ec4ff0e8acc5d8e48522e4bbfd1d700d` (11,514,300 bytes).
  - Official uncompressed `Image`: SHA256 `817bebc6898dd98d341ba084ce889e100babb8699238e2153043e1727c644e4f` (40,351,768 bytes).
  - Official `kernel.dtb`: SHA256 `f8cd4e2560a4a8a30d9c7aea2093ef753c5d4703e902a4ea65266e98e15dbe99` (342,362 bytes).
  - Baseline `ramdisk.img`: SHA256 `685f11d004aba791bbdd0d9d4c0129df8dbcc4ed87fef41a2a4dfb57f69545e8` (1,399,200 bytes).
  - Packaged test boot: `boot-revenant-r1.1.108-official-test.img` (SHA256 `8cee40403d8b4179830eb011ad187f98599ac85c296ee3cd338dc7c6c7e41812`, 18,554,880 bytes).
  - Audit: Unpacked test image verified byte-for-byte identical to official kernel and DTB. No ACS patch, no KSU, no SUSFS.
* **Physical Hardware Execution**:
  - Image flashed to `/dev/block/bootdevice/by-name/boot` in OrangeFox recovery; readback SHA256 verified identical.
  - Reboot executed.
* **Observed Behavior**:
  - Device froze immediately at OEM splash screen ("Redmi").
  - 60+ seconds elapsed without USB enumeration, ADB response, or kernel execution transition.
  - Behavior matched previous candidate tests (P3.2.2 and board-id experiment).
* **Rollback Protocol**:
  - Device rebooted to OrangeFox recovery.
  - `boot-stock.img` (SHA256 `82a102198fd9b2bbfb856fc3057afb9e30e454fee76d392bf50afcc92d6dc220`) written to `/dev/block/bootdevice/by-name/boot` and readback verified.
  - Device rebooted and returned to `sys.boot_completed=1` under stock kernel `4.19.325-cip132-st16-perf-g54f411d70954`.
* **Causal Diagnosis & Defconfig Discovery (P3.2.4)**:
  - Falsified the assumption that `extract-ikconfig` output represented the compilation recipe: `kernel/Makefile` lines 131-133 contain a static hardcoded rule committed in 2020 (`1b3cc5c195c6`) that injects `sdm660-perf-full_defconfig` into `config_data.gz` as a userspace spoof.
  - Confirmed that the official upstream release binary `San-Kernel-Revenant-R1.1.108` itself fails to boot on this hardware platform.
* **Verdict**: `[FAIL]` (`OFFICIAL RELEASE NON-BOOTABLE ON THIS WHYRED`). Rollback to stock: `[PASS]`.

