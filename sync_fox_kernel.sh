#!/usr/bin/env bash
# ==============================================================================
# LineageOS to OrangeFox Prebuilt Kernel Synchronizer
# ==============================================================================
# Synchronizes the freshly compiled Linux 4.19 kernel (Image.gz-dtb) from
# LineageOS out directory into the OrangeFox recovery device tree, commits
# the change, and optionally triggers cloud compilation via GitHub Actions.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

DEVICE="${DEVICE:-whyred}"
FOX_DIR="${FOX_DIR:-../orangefox_device_xiaomi_whyred}"
OUT_DIR="${OUT_DIR:-out/target/product/${DEVICE}}"
SRC_KERNEL="${OUT_DIR}/Image.gz-dtb-stock"
[ ! -f "${SRC_KERNEL}" ] && SRC_KERNEL="${OUT_DIR}/obj/KERNEL_OBJ/arch/arm64/boot/Image.gz-dtb"
[ ! -f "${SRC_KERNEL}" ] && SRC_KERNEL="${OUT_DIR}/kernel"

DEST_KERNEL="${FOX_DIR}/prebuilt/Image.gz-dtb"

FOX_REMOTE_URL=$(git -C "${FOX_DIR}" remote get-url origin 2>/dev/null || echo "")
FOX_REPO=$(echo "${FOX_REMOTE_URL}" | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?#\1#' || true)
[ -z "${FOX_REPO}" ] && FOX_REPO="kveld9/orangefox_device_xiaomi_whyred"

ACTION="${1:-check}"

print_help() {
    cat <<HELPEOF
Usage: ./sync_fox_kernel.sh [ACTION]

Actions:
  check (default)  Compare hashes between LineageOS kernel and OrangeFox prebuilt
  --sync           Copy new kernel, commit, and push to OrangeFox repo
  --build          Sync kernel (if changed) and trigger OrangeFox cloud build on GitHub Actions
  --trigger-only   Trigger OrangeFox cloud build on GitHub Actions directly
  --help, -h       Show this help message

Environment overrides:
  DEVICE           Target device codename (default: whyred)
  FOX_DIR          Path to orangefox_device_xiaomi_whyred repo (default: ../orangefox_device_xiaomi_whyred)
HELPEOF
}

case "${ACTION}" in
    --help|-h)
        print_help
        exit 0
        ;;
    check|--sync|--build|--trigger-only)
        ;;
    *)
        echo "[WARN] Unknown action: ${ACTION}"
        print_help
        exit 1
        ;;
esac

trigger_cloud_build() {
    echo "[INFO] Triggering OrangeFox Recovery build in GitHub Actions..."
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        gh workflow run build.yml -R "${FOX_REPO}" \
            -f MANIFEST_BRANCH="12.1" \
            -f BUILD_TYPE="Unofficial"
        echo "[OK] Workflow dispatched successfully via GitHub CLI."
        echo "Monitor build at: https://github.com/${FOX_REPO}/actions"
    else
        echo "[WARN] GitHub CLI ('gh') not authenticated. Trigger build manually or via Telegram (/build_fox)."
    fi
}

if [ "${ACTION}" = "--trigger-only" ]; then
    trigger_cloud_build
    exit 0
fi

echo "=========================================================="
echo " [INFO] OrangeFox Prebuilt Kernel Synchronizer (${DEVICE})"
echo "=========================================================="

if [ ! -d "${FOX_DIR}" ]; then
    echo "[ERROR] OrangeFox repository directory not found at: ${FOX_DIR}"
    exit 1
fi

if [ ! -f "${SRC_KERNEL}" ]; then
    echo "[ERROR] LineageOS kernel binary not found at: ${SRC_KERNEL}"
    echo "Compile LineageOS first via: ./build_whyred.sh --build"
    exit 1
fi

# Verify kernel is not a rooted variant (inspect decompressed stream and raw bytes)
if (gzip -dc "${SRC_KERNEL}" 2>/dev/null || true) | strings | grep -E '(-perf-resukisu|-perf-ksu|KernelSU|ReSukiSU)' >/dev/null || \
   strings "${SRC_KERNEL}" 2>/dev/null | grep -E '(-perf-resukisu|-perf-ksu|KernelSU|ReSukiSU)' >/dev/null; then
    echo "[ERROR] Refusing to synchronize rooted kernel variant to OrangeFox recovery: ${SRC_KERNEL}"
    echo "The prebuilt recovery kernel must be a clean stock LineageOS kernel."
    exit 1
fi

SRC_HASH=$(sha256sum "${SRC_KERNEL}" | awk '{print $1}')
DEST_HASH=$(sha256sum "${DEST_KERNEL}" 2>/dev/null | awk '{print $1}' || echo "missing")
REMOTE_HASH=$(git -C "${FOX_DIR}" show origin/main:prebuilt/Image.gz-dtb 2>/dev/null | sha256sum | awk '{print $1}' || echo "unknown")
DIRTY_PREBUILT=$(git -C "${FOX_DIR}" status --porcelain prebuilt/Image.gz-dtb 2>/dev/null || true)
UNPUSHED=$(git -C "${FOX_DIR}" rev-list --count origin/main..HEAD 2>/dev/null || echo 0)

echo "Source LineageOS Kernel: ${SRC_HASH}"
echo "OrangeFox Prebuilt:      ${DEST_HASH}"
echo "OrangeFox Remote (main): ${REMOTE_HASH}"

if [ "${SRC_HASH}" = "${DEST_HASH}" ] && [ -z "${DIRTY_PREBUILT}" ] && [ "${SRC_HASH}" = "${REMOTE_HASH}" ] && [ "${UNPUSHED}" -eq 0 ]; then
    echo ""
    echo "[OK] OrangeFox prebuilt kernel is already in sync with LineageOS and pushed to remote."
    if [ "${ACTION}" = "--build" ]; then
        trigger_cloud_build
    fi
    exit 0
fi

echo ""
echo "[UPDATE] New kernel detected in LineageOS build output."

if [ "${ACTION}" = "check" ]; then
    echo "To synchronize, commit, and push, run:"
    echo "  ./sync_fox_kernel.sh --sync"
    echo "To synchronize and trigger cloud compilation, run:"
    echo "  ./sync_fox_kernel.sh --build"
    exit 0
fi

# Synchronize
echo "[1/3] Copying ${SRC_KERNEL} -> ${DEST_KERNEL}..."
mkdir -p "${FOX_DIR}/prebuilt"
cp -f "${SRC_KERNEL}" "${DEST_KERNEL}"

# Extract kernel version
KERNEL_VER=$(awk '/^VERSION =/ {v=$3} /^PATCHLEVEL =/ {p=$3} /^SUBLEVEL =/ {s=$3} END {print v "." p "." s}' kernel/xiaomi/sdm660/Makefile 2>/dev/null || echo "4.19")

# Commit in OrangeFox repository
echo "[2/3] Committing updated prebuilt kernel in OrangeFox repository..."
git -C "${FOX_DIR}" add prebuilt/Image.gz-dtb
git -C "${FOX_DIR}" commit -m "chore(kernel): sync prebuilt Image.gz-dtb with lineageos kernel (${KERNEL_VER})"
echo "[OK] Committed: $(git -C "${FOX_DIR}" log -1 --oneline)"

# Push
echo "[3/3] Pushing changes to origin main..."
git -C "${FOX_DIR}" push origin main
echo "[OK] Pushed to ${FOX_REPO}."

if [ "${ACTION}" = "--build" ]; then
    echo ""
    trigger_cloud_build
fi

echo "=========================================================="
echo " [OK] OrangeFox kernel synchronization completed."
echo "=========================================================="
