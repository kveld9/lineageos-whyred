#!/usr/bin/env bash
# ==============================================================================
# debloat_whyred.sh — Modular ADB Debloater for Xiaomi Redmi Note 5 Pro (whyred)
# LineageOS 21.0 (Android 14)
# ==============================================================================
# Usage:
#   ./debloat_whyred.sh             # Debloat all enabled packages for user 0
#   ./debloat_whyred.sh --restore   # Restore previously uninstalled packages
#   ./debloat_whyred.sh --dry-run   # Preview actions without modifying device
#   ./debloat_whyred.sh --list      # Display all registered packages by section
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Package Registry (Edit, comment out with '#', or add packages here)
# ------------------------------------------------------------------------------

# Section 1: Telemetry, Tracking & Unused Daemons
readonly TELEMETRY_AND_DAEMONS=(
    "com.android.nfc"                                    # NFC absent on whyred hardware
    "org.lineageos.updater"                              # Inactive on unofficial builds
    "org.lineageos.updater.auto_generated_rro_product__" # OTA Updater RRO overlay
    "com.tencent.soter.soterserver"                      # WeChat biometric daemon (China)
    "com.dsi.ant.server"                                 # ANT+ radio daemon (unused)
    "org.ifaa.aidl.manager"                              # Alipay payment framework (unused)
    "com.stevesoltys.seedvault"                          # Seedvault background backup
    "org.calyxos.backup.contacts"                        # CalyxOS contact backup provider
    "com.android.adservices.api"                         # Privacy Sandbox / Ad measurement
    "com.android.federatedcompute.services"              # Federated compute ML telemetry
    "com.android.ondevicepersonalization.services"       # On-device personalization tracking
    "com.android.bips"                                   # Built-in print discovery service
    "com.android.printservice.recommendation"            # Background print service scanner
    "com.android.stk"                                    # SIM Application Toolkit popups
    "com.caf.fmradio"                                    # FM radio analog tuner
    "com.qualcomm.embms"                                 # LTE Broadcast eMBMS framework
    "com.qti.dpmserviceapp"                              # Qualcomm Data Port Management
    "com.android.DeviceAsWebcam"                         # Virtual USB webcam mode
    "com.android.emergency"                              # AOSP emergency assistance shortcut
    "com.android.bookmarkprovider"                       # Legacy bookmark content provider
    "com.android.cts.ctsshim"                            # CTS test runner shim stub
    "com.android.cts.priv.ctsshim"                       # CTS privileged test shim stub
    "com.android.egg"                                    # Android 14 Easter Egg
    "com.android.htmlviewer"                             # Basic HTML preview fallback
    "com.google.android.apps.googlecamera.fishfood"      # Google Camera dogfood stub
    "com.android.dreams.basic"                           # Default screensaver component
    "com.android.dreams.phototable"                      # Photo screensaver component
    "com.android.wallpaper.livepicker"                   # Live wallpaper picker engine
    "com.android.wallpaperbackup"                        # Wallpaper cloud sync helper
    "com.android.cellbroadcastreceiver"                  # Emergency cell broadcast receiver
    "com.android.cellbroadcastreceiver.module"           # Emergency cell broadcast module
    "com.android.cellbroadcastservice"                   # Background cell broadcast service
    "com.android.smspush"                                # Legacy WAP push message receiver
    "com.android.simappdialog"                           # Carrier dialog display framework
    "com.android.carrierdefaultapp"                      # Fallback carrier provisioning app
    "com.android.pacprocessor"                           # Proxy Auto-Config PAC parser
    "com.android.proxyhandler"                           # Proxy connection handler daemon
    "com.fingerprints.extension.service"                 # Legacy FPC fingerprint extension
)

# Section 2: LineageOS Multimedia & Utilities
readonly LINEAGEOS_MULTIMEDIA=(
    "org.lineageos.jelly"                                # Jelly Web Browser
    "org.lineageos.eleven"                               # Eleven Music Player
    "org.lineageos.recorder"                             # LineageOS Sound Recorder
    "org.lineageos.audiofx"                              # AudioFX DSP Equalizer
    "org.lineageos.backgrounds"                          # Stock wallpaper asset bundle
    "org.lineageos.profiles"                             # System Profiles switcher
    "org.lineageos.setupwizard"                          # Initial device setup wizard
    "org.lineageos.setupwizard.auto_generated_rro_product__" # Setup wizard overlay
)

# Section 3: Background Sync & System Agents
readonly BACKGROUND_AND_SYNC=(
    "com.android.backupconfirm"                          # Desktop adb backup confirmation
    "com.android.bluetoothmidiservice"                   # Bluetooth LE MIDI service
    "com.android.cameraextensions"                       # Camera OEM vendor extension stub
    "com.android.calllogbackup"                          # Call log cloud backup provider
    "com.android.dynsystem"                              # Dynamic System Update (DSU GSI)
    "com.android.health.connect.backuprestore"           # Health Connect backup restore
    "com.android.healthconnect.controller"               # Health Connect controller
    "com.android.localtransport"                         # Local loopback backup transport
    "com.android.managedprovisioning"                    # Work profile enterprise MDM
    "com.android.ons"                                    # Opportunistic Network Service
    "com.android.providers.settings.auto_generated_rro_product__" # Settings RRO overlay
    "com.android.providers.userdictionary"               # Keyboard user dictionary store
    "com.android.rkpdapp"                                # Remote Key Provisioning daemon
    "com.android.role.notes.enabled"                     # Default notes app role helper
    "com.android.safetycenter.resources"                 # Safety Center UI assets
    "com.android.settings.intelligence"                  # Settings search indexer
    "com.android.sharedstoragebackup"                    # Shared external storage backup
    "com.android.systemui.accessibility.accessibilitymenu" # Floating accessibility button
    "com.android.systemui.plugin.globalactions.wallet"   # Power menu wallet card shortcut
    "com.android.virtualmachine.res"                     # Microdroid VM virtualization assets
)

# Section 4: System & Theme Overlays (AOSP Theme Engine)
readonly THEME_OVERLAYS=(
    # Icon Packs (24 variants)
    "com.android.theme.icon_pack.circular.android"
    "com.android.theme.icon_pack.circular.launcher"
    "com.android.theme.icon_pack.circular.settings"
    "com.android.theme.icon_pack.circular.systemui"
    "com.android.theme.icon_pack.filled.android"
    "com.android.theme.icon_pack.filled.launcher"
    "com.android.theme.icon_pack.filled.settings"
    "com.android.theme.icon_pack.filled.systemui"
    "com.android.theme.icon_pack.kai.android"
    "com.android.theme.icon_pack.kai.launcher"
    "com.android.theme.icon_pack.kai.settings"
    "com.android.theme.icon_pack.kai.systemui"
    "com.android.theme.icon_pack.rounded.android"
    "com.android.theme.icon_pack.rounded.launcher"
    "com.android.theme.icon_pack.rounded.settings"
    "com.android.theme.icon_pack.rounded.systemui"
    "com.android.theme.icon_pack.sam.android"
    "com.android.theme.icon_pack.sam.launcher"
    "com.android.theme.icon_pack.sam.settings"
    "com.android.theme.icon_pack.sam.systemui"
    "com.android.theme.icon_pack.victor.android"
    "com.android.theme.icon_pack.victor.launcher"
    "com.android.theme.icon_pack.victor.settings"
    "com.android.theme.icon_pack.victor.systemui"
    # Icon Shapes (7 variants)
    "com.android.theme.icon.pebble"
    "com.android.theme.icon.roundedrect"
    "com.android.theme.icon.square"
    "com.android.theme.icon.squircle"
    "com.android.theme.icon.taperedrect"
    "com.android.theme.icon.teardrop"
    "com.android.theme.icon.vessel"
    # Fonts (3 variants)
    "org.lineageos.overlay.font.lato"
    "org.lineageos.overlay.font.rubik"
    "com.android.theme.font.notoserifsource"
    # System Overlays (2 variants)
    "android.auto_generated_rro_product__"
    "android.auto_generated_rro_vendor__"
)

# ------------------------------------------------------------------------------
# UI Styles & Helpers
# ------------------------------------------------------------------------------
readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD="\033[1m"
readonly COLOR_GREEN="\033[32m"
readonly COLOR_YELLOW="\033[33m"
readonly COLOR_RED="\033[31m"
readonly COLOR_CYAN="\033[36m"

log_info()    { printf "%b[INFO]%b %s\n" "${COLOR_CYAN}" "${COLOR_RESET}" "$*"; }
log_success() { printf "%b[  OK]%b %s\n" "${COLOR_GREEN}" "${COLOR_RESET}" "$*"; }
log_skip()    { printf "%b[SKIP]%b %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$*"; }
log_warn()    { printf "%b[WARN]%b %s\n" "${COLOR_YELLOW}" "${COLOR_RESET}" "$*"; }
log_error()   { printf "%b[FAIL]%b %s\n" "${COLOR_RED}" "${COLOR_RESET}" "$*"; }

# ------------------------------------------------------------------------------
# Device Connection Guard
# ------------------------------------------------------------------------------
check_adb_device() {
    if ! command -v adb >/dev/null 2>&1; then
        log_error "adb binary not found in PATH. Install android-tools or Android SDK."
        exit 1
    fi

    local device_count
    device_count=$(adb devices | grep -cv "List of devices attached\|^$" || true)

    if [[ "${device_count}" -eq 0 ]]; then
        log_error "No device connected via ADB. Enable USB debugging and reconnect."
        exit 1
    fi

    local device_model
    device_model=$(adb shell getprop ro.product.device 2>/dev/null | tr -d '\r')
    log_info "Connected device: ${COLOR_BOLD}${device_model:-unknown}${COLOR_RESET}"
}

# ------------------------------------------------------------------------------
# Core Execution Engine
# ------------------------------------------------------------------------------
declare -A ENABLED_PACKAGES=()

init_package_cache() {
    ENABLED_PACKAGES=()
    local raw_list
    raw_list=$(adb shell pm list packages -e --user 0 2>/dev/null | tr -d '\r' || true)
    while IFS= read -r line; do
        local pkg_name="${line#package:}"
        if [[ -n "${pkg_name}" ]]; then
            ENABLED_PACKAGES["${pkg_name}"]=1
        fi
    done <<< "${raw_list}"
}

run_package_action() {
    local -r mode="$1"
    local -r pkg="$2"

    if [[ "${mode}" == "list" ]]; then
        printf "  • %s\n" "${pkg}"
        return 0
    fi

    if [[ "${mode}" == "dry-run" ]]; then
        if [[ -n "${ENABLED_PACKAGES["${pkg}"]:-}" ]]; then
            log_info "[DRY-RUN] Would debloat (currently active): ${pkg}"
        else
            log_skip "[DRY-RUN] Already removed or disabled: ${pkg}"
        fi
        return 0
    fi

    if [[ "${mode}" == "restore" ]]; then
        local out_enable out_install
        out_enable=$(adb shell pm enable "${pkg}" 2>&1 | tr -d '\r' || true)
        out_install=$(adb shell cmd package install-existing "${pkg}" 2>&1 | tr -d '\r' || true)

        if echo "${out_enable}" | grep -qi "new state: enabled" || \
           echo "${out_install}" | grep -qE "installed for user|already installed"; then
            log_success "Restored: ${pkg}"
            return 0
        fi
        log_skip "Cannot restore (not on system partition): ${pkg}"
        return 0
    fi

    # Mode: uninstall (default)
    if [[ -z "${ENABLED_PACKAGES["${pkg}"]:-}" ]]; then
        log_skip "Already removed/disabled: ${pkg}"
        return 0
    fi

    local out
    out=$(adb shell pm uninstall --user 0 "${pkg}" 2>&1 | tr -d '\r' || true)
    if echo "${out}" | grep -qi "Success"; then
        log_success "Removed: ${pkg}"
        return 0
    fi

    # Fallback to disabling if system forbids uninstallation
    local out_disable
    out_disable=$(adb shell pm disable-user --user 0 "${pkg}" 2>&1 | tr -d '\r' || true)
    if echo "${out_disable}" | grep -qi "new state: disabled-user"; then
        log_success "Disabled (uninstall restricted): ${pkg}"
        return 0
    fi

    log_error "Failed to remove or disable ${pkg}: ${out} / ${out_disable}"
    return 1
}

# ------------------------------------------------------------------------------
# CLI Dispatcher
# ------------------------------------------------------------------------------
main() {
    local mode="uninstall"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --restore|-r)
                mode="restore"
                shift
                ;;
            --dry-run|-n)
                mode="dry-run"
                shift
                ;;
            --list|-l)
                mode="list"
                shift
                ;;
            --help|-h)
                printf "%b" "${COLOR_BOLD}debloat_whyred.sh${COLOR_RESET} — LineageOS 21.0 ADB Debloater\n\n"
                printf "Usage:\n"
                printf "  %s             Uninstall safe bloatware packages for user 0\n" "$0"
                printf "  %s --restore   Re-install uninstalled packages\n" "$0"
                printf "  %s --dry-run   Preview packages to be processed\n" "$0"
                printf "  %s --list      Print all registered packages by category\n" "$0"
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1. Run with --help for options."
                exit 1
                ;;
        esac
    done

    local -r categories=(
        "TELEMETRY_AND_DAEMONS:Telemetry, Tracking & Unused Daemons"
        "LINEAGEOS_MULTIMEDIA:LineageOS Multimedia & Utilities"
        "BACKGROUND_AND_SYNC:Background Sync & System Agents"
        "THEME_OVERLAYS:System & Theme Overlays"
    )

    if [[ "${mode}" != "list" ]]; then
        check_adb_device
        init_package_cache
        printf "\n%bMode:%b %s\n" "${COLOR_BOLD}" "${COLOR_RESET}" "${mode}"
        printf "%s\n\n" "================================================================="
    fi

    local count_total=0
    local count_success=0
    local count_skipped=0
    local count_failed=0

    for cat_def in "${categories[@]}"; do
        local var_name="${cat_def%%:*}"
        local title="${cat_def#*:}"

        printf "\n%b=== %s ===%b\n" "${COLOR_BOLD}" "${title}" "${COLOR_RESET}"

        local -n pkg_list="${var_name}"
        for pkg in "${pkg_list[@]}"; do
            ((count_total++)) || true
            if run_package_action "${mode}" "${pkg}"; then
                ((count_success++)) || true
            else
                ((count_failed++)) || true
            fi
        done
    done

    if [[ "${mode}" != "list" ]]; then
        printf "\n%s\n" "================================================================="
        printf "%bSummary:%b Total: %d | Processed/OK: %d | Errors: %d\n" \
            "${COLOR_BOLD}" "${COLOR_RESET}" "${count_total}" "${count_success}" "${count_failed}"
        printf "%s\n" "================================================================="
    fi
}

main "$@"
