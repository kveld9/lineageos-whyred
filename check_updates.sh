#!/usr/bin/env bash
# ==============================================================================
# LineageOS Upstream & Security Patch Monitor
# ==============================================================================
# Autonomously checks upstream LineageOS repositories for new monthly Android
# Security Bulletins (ASB) and pending commits across device, kernel, and
# platform trees.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

DEVICE="${DEVICE:-whyred}"
BRANCH_PLATFORM="${BRANCH_PLATFORM:-lineage-21.0}"
BRANCH_DEVICE="${BRANCH_DEVICE:-lineage-21}"

DO_FETCH=true
DO_NOTIFY=false
VERBOSE=false

print_help() {
    cat <<HELPEOF
Usage: ./check_updates.sh [OPTIONS]

Options:
  --notify        Send desktop notification via notify-send if updates exist
  --no-fetch      Skip fetching remotes; compare against cached tracking refs
  --verbose       Display detailed commit subjects for pending updates
  --help, -h      Show this help message

Environment overrides:
  DEVICE          Target device codename (default: whyred)
  BRANCH_PLATFORM Upstream platform branch (default: lineage-21.0)
  BRANCH_DEVICE   Upstream device/kernel branch (default: lineage-21)
HELPEOF
}

# Parse CLI options
for arg in "$@"; do
    case "${arg}" in
        --notify)
            DO_NOTIFY=true
            ;;
        --no-fetch)
            DO_FETCH=false
            ;;
        --verbose)
            VERBOSE=true
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            echo "[WARN] Unknown argument: ${arg}"
            ;;
    esac
done

fetch_remote() {
    local dir="$1"
    local remote="$2"
    local ref="$3"

    if [ "${DO_FETCH}" = true ] && [ -d "${dir}/.git" ]; then
        git -C "${dir}" fetch --quiet "${remote}" "${ref}" 2>/dev/null || true
    fi
}

extract_patch_level() {
    local target="$1"
    local patch=""

    if [ -f "${target}" ]; then
        patch=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "${target}" | head -n 1 || true)
    fi
    echo "${patch:-unknown}"
}

echo "=========================================================="
echo " [INFO] Checking LineageOS Upstream Status (${DEVICE})"
echo "=========================================================="

# 1. Platform Security Patch Level (ASB)
RELEASE_DIR="build/release"
LOCAL_ASB="unknown"
UPSTREAM_ASB="unknown"
ASB_CHANGED=false

if [ -d "${RELEASE_DIR}/.git" ]; then
    fetch_remote "${RELEASE_DIR}" "github" "${BRANCH_PLATFORM}"

    LOCAL_PROTO="${RELEASE_DIR}/flag_values/ap2a/RELEASE_PLATFORM_SECURITY_PATCH.textproto"
    LOCAL_ASB=$(extract_patch_level "${LOCAL_PROTO}")

    # Inspect upstream ref
    UPSTREAM_PROTO_CONTENT=$(git -C "${RELEASE_DIR}" show "github/${BRANCH_PLATFORM}:flag_values/ap2a/RELEASE_PLATFORM_SECURITY_PATCH.textproto" 2>/dev/null || true)
    if [ -n "${UPSTREAM_PROTO_CONTENT}" ]; then
        UPSTREAM_ASB=$(echo "${UPSTREAM_PROTO_CONTENT}" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -n 1 || true)
    fi

    if [ "${LOCAL_ASB}" != "unknown" ] && [ "${UPSTREAM_ASB}" != "unknown" ] && [ "${LOCAL_ASB}" != "${UPSTREAM_ASB}" ]; then
        ASB_CHANGED=true
    fi
fi

echo ""
echo "[1/4] Android Security Bulletin (ASB) Status:"
echo "  - Local Security String:    ${LOCAL_ASB}"
echo "  - Upstream Security String: ${UPSTREAM_ASB}"

if [ "${ASB_CHANGED}" = true ]; then
    echo "  - Status:                   [UPDATE AVAILABLE] (New ASB: ${UPSTREAM_ASB})"
else
    echo "  - Status:                   [UP TO DATE]"
fi

# 2. Subsystem Upstream Inspections
echo ""
echo "[2/4] Inspecting Subsystem Repositories:"

TOTAL_PENDING_COMMITS=0

check_repo() {
    local name="$1"
    local path="$2"
    local remote="$3"
    local branch="$4"

    if [ ! -d "${path}/.git" ]; then
        echo "  - ${name}: [SKIPPED] (Path ${path} not found)"
        return
    fi

    fetch_remote "${path}" "${remote}" "${branch}"

    local count=0
    local target_ref="${remote}/${branch}"

    if git -C "${path}" rev-parse --verify "${target_ref}" >/dev/null 2>&1; then
        count=$(git -C "${path}" rev-list --count "HEAD..${target_ref}" 2>/dev/null || echo 0)
    fi

    if [ "${count}" -gt 0 ]; then
        echo "  - ${name}: [PENDING] ${count} new commit(s) upstream (${target_ref})"
        TOTAL_PENDING_COMMITS=$(( TOTAL_PENDING_COMMITS + count ))
        if [ "${VERBOSE}" = true ]; then
            git -C "${path}" log "HEAD..${target_ref}" --oneline -n 5 | sed 's/^/      * /'
        fi
    else
        echo "  - ${name}: [UP TO DATE]"
    fi
}

check_repo "Kernel (sdm660)" "kernel/xiaomi/sdm660" "github" "${BRANCH_DEVICE}"
check_repo "Common Device Tree" "device/xiaomi/sdm660-common" "github" "${BRANCH_DEVICE}"
check_repo "Hardware Xiaomi" "hardware/xiaomi" "github" "${BRANCH_DEVICE}"
check_repo "Build System (make)" "build/make" "github" "${BRANCH_PLATFORM}"
check_repo "Build Release Flags" "build/release" "github" "${BRANCH_PLATFORM}"

# 3. Kernel Variant Branches Parity
echo ""
echo "[3/4] Kernel Variant Branches Parity:"
KERNEL_PATH="kernel/xiaomi/sdm660"
if [ -d "${KERNEL_PATH}/.git" ]; then
    for branch in lineage-21 lineage-21-ksu lineage-21-resukisu; do
        if git -C "${KERNEL_PATH}" rev-parse --verify "${branch}" >/dev/null 2>&1; then
            local_hash=$(git -C "${KERNEL_PATH}" rev-parse --short "${branch}" 2>/dev/null)
            echo "  - Branch ${branch}: ${local_hash}"
        fi
    done
fi

# 4. Summary & Action Verdict
echo ""
echo "[4/4] Summary & Verdict:"
if [ "${ASB_CHANGED}" = true ] || [ "${TOTAL_PENDING_COMMITS}" -gt 0 ]; then
    echo "  [ACTION REQUIRED]"
    [ "${ASB_CHANGED}" = true ] && echo "  * New Monthly ASB detected (${LOCAL_ASB} -> ${UPSTREAM_ASB})"
    [ "${TOTAL_PENDING_COMMITS}" -gt 0 ] && echo "  * Total pending upstream commits: ${TOTAL_PENDING_COMMITS}"
    echo ""
    echo "  Recommended Workflow:"
    echo "    1. Review incoming changes:    ./check_updates.sh --verbose"
    echo "    2. Siphon upstream platform:   repo sync -j\$(nproc)"
    echo "    3. Port/verify kernel parity:  git -C kernel/xiaomi/sdm660 ..."
    echo "    4. Compile ROM & Kernels:      ./build_whyred.sh --all"
    echo "    5. Verify on hardware:         Flash and check calls/wifi/camera"
    echo "    6. Update AUDIT_REGISTRY.md & publish release."

    if [ "${DO_NOTIFY}" = true ] && command -v notify-send >/dev/null 2>&1; then
        notify_msg="New LineageOS update available! ASB: ${UPSTREAM_ASB}, Pending commits: ${TOTAL_PENDING_COMMITS}"
        notify-send -u normal "LineageOS Update Available (${DEVICE})" "${notify_msg}" 2>/dev/null || true
    fi
else
    echo "  [UP TO DATE] No new security patches or subsystem commits upstream."
    echo "  No compilation or release needed at this time."
fi
echo "=========================================================="
