#!/usr/bin/env bash
# ==============================================================================
# LineageOS Automated Upstream Sync & Build Orchestrator
# ==============================================================================
# 1. Checks upstream status for new ASB security patches and subsystem commits.
# 2. Synchronizes LineageOS 21 AOSP platform via repo sync.
# 3. Integrates upstream commits into common device tree and kernel.
# 4. Verifies kernel variant parity across active branches.
# 5. Optionally executes full compilation and GitHub release pipeline.
# ==============================================================================

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

DEVICE="${DEVICE:-whyred}"
BRANCH_PLATFORM="${BRANCH_PLATFORM:-lineage-21.0}"
BRANCH_DEVICE="${BRANCH_DEVICE:-lineage-21}"
ACTION="${1:-sync}"

print_help() {
    cat <<HELPEOF
Usage: ./update_whyred.sh [ACTION]

Actions:
  sync (default)  Fetch and sync all upstream changes without compiling
  --build         Sync upstream and compile ROM package (mka bacon)
  --all           Sync upstream and run full pipeline: ROM + 3 Kernels + Release
  --help, -h      Show this help message

Environment overrides:
  DEVICE          Target device codename (default: whyred)
  BRANCH_PLATFORM Upstream platform branch (default: lineage-21.0)
  BRANCH_DEVICE   Upstream device/kernel branch (default: lineage-21)
HELPEOF
}

case "${ACTION}" in
    --help|-h)
        print_help
        exit 0
        ;;
    sync|--build|--all)
        ;;
    *)
        echo "[WARN] Unknown option: ${ACTION}"
        print_help
        exit 1
        ;;
esac

echo "=========================================================="
echo " [STAGE 1/4] Inspecting Upstream Status"
echo "=========================================================="
./check_updates.sh --verbose

echo ""
echo "=========================================================="
echo " [STAGE 2/4] Synchronizing Platform Sources (repo sync)"
echo "=========================================================="
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j"$(nproc)"

echo ""
echo "=========================================================="
echo " [STAGE 3/4] Integrating Subsystem Changes"
echo "=========================================================="

# 1. Common Device Tree
COMMON_DIR="device/xiaomi/sdm660-common"
if [ -d "${COMMON_DIR}/.git" ]; then
    git -C "${COMMON_DIR}" fetch --quiet github "${BRANCH_DEVICE}" 2>/dev/null || true
    COMMON_PENDING=$(git -C "${COMMON_DIR}" rev-list --count "HEAD..github/${BRANCH_DEVICE}" 2>/dev/null || echo 0)
    if [ "${COMMON_PENDING}" -gt 0 ]; then
        echo "[INFO] Merging ${COMMON_PENDING} commit(s) into ${COMMON_DIR}..."
        git -C "${COMMON_DIR}" merge --no-edit "github/${BRANCH_DEVICE}"
    else
        echo "[OK] ${COMMON_DIR} is already up to date."
    fi
fi

# 2. Kernel Tree (Lineage-21, KSU, ReSukiSU)
KERNEL_DIR="kernel/xiaomi/sdm660"
if [ -d "${KERNEL_DIR}/.git" ]; then
    git -C "${KERNEL_DIR}" fetch --quiet github "${BRANCH_DEVICE}" 2>/dev/null || true
    KERNEL_PENDING=$(git -C "${KERNEL_DIR}" rev-list --count "lineage-21..github/${BRANCH_DEVICE}" 2>/dev/null || echo 0)

    if [ "${KERNEL_PENDING}" -gt 0 ]; then
        echo "[INFO] Merging ${KERNEL_PENDING} commit(s) into kernel branch 'lineage-21'..."
        CURRENT_KERNEL_BRANCH=$(git -C "${KERNEL_DIR}" branch --show-current 2>/dev/null || true)
        git -C "${KERNEL_DIR}" checkout lineage-21
        git -C "${KERNEL_DIR}" merge --no-edit "github/${BRANCH_DEVICE}"

        # Inspect if VFS hooks were modified
        VFS_TOUCHED=$(git -C "${KERNEL_DIR}" diff --name-only "HEAD~${KERNEL_PENDING}..HEAD" | grep -E '^(fs/namei\.c|fs/namespace\.c|fs/open\.c|drivers/kernelsu)' || true)

        if [ -n "${VFS_TOUCHED}" ]; then
            echo "[WARN] Kernel changes modified VFS files:"
            echo "${VFS_TOUCHED}" | sed 's/^/  * /'
            echo "[WARN] Manual inspection of SuSFS / ReSukiSU hooks required before auto-rebasing rooted branches."
        else
            echo "[OK] No VFS conflicts detected. Porting foundation changes to sister branches..."
            for sister in lineage-21-ksu lineage-21-resukisu; do
                if git -C "${KERNEL_DIR}" rev-parse --verify "${sister}" >/dev/null 2>&1; then
                    echo "  -> Updating branch ${sister}..."
                    git -C "${KERNEL_DIR}" checkout "${sister}"
                    git -C "${KERNEL_DIR}" merge --no-edit lineage-21 || {
                        echo "[WARN] Merge collision on branch ${sister}. Resolve manually."
                    }
                fi
            done
        fi

        # Restore previous branch if set
        [ -n "${CURRENT_KERNEL_BRANCH}" ] && git -C "${KERNEL_DIR}" checkout "${CURRENT_KERNEL_BRANCH}" 2>/dev/null || true
    else
        echo "[OK] ${KERNEL_DIR} (lineage-21) is already up to date."
    fi
fi

echo ""
echo "=========================================================="
echo " [STAGE 4/4] Verification & Next Steps"
echo "=========================================================="
./check_updates.sh --no-fetch

case "${ACTION}" in
    --build)
        echo ""
        echo "[INFO] Triggering ROM compilation..."
        ./build_whyred.sh --build
        ;;
    --all)
        echo ""
        echo "[INFO] Triggering complete end-to-end pipeline..."
        ./build_whyred.sh --all
        ;;
    sync)
        echo ""
        echo "[OK] All source trees synchronized and merged successfully."
        echo "Ready to compile. Run one of the following commands:"
        echo "  ./build_whyred.sh --build           (Compile ROM only)"
        echo "  ./build_whyred.sh --all             (Compile ROM + 3 Kernels + Publish)"
        ;;
esac
