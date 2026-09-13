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
    COMMON_PENDING=0
    if git -C "${COMMON_DIR}" merge-base "HEAD" "github/${BRANCH_DEVICE}" >/dev/null 2>&1; then
        COMMON_PENDING=$(git -C "${COMMON_DIR}" rev-list --count "HEAD..github/${BRANCH_DEVICE}" 2>/dev/null || echo 0)
    fi
    if [ "${COMMON_PENDING}" -gt 0 ]; then
        echo "[INFO] Merging ${COMMON_PENDING} commit(s) into ${COMMON_DIR}..."
        if ! git -C "${COMMON_DIR}" merge --no-edit "github/${BRANCH_DEVICE}"; then
            echo "[ERROR] Merge collision on ${COMMON_DIR}. Aborting merge."
            git -C "${COMMON_DIR}" merge --abort
            exit 1
        fi
    else
        echo "[OK] ${COMMON_DIR} is already up to date."
    fi
fi

# 2. Kernel Tree (Lineage-21, KSU, ReSukiSU)
KERNEL_DIR="kernel/xiaomi/sdm660"
if [ -d "${KERNEL_DIR}/.git" ]; then
    git -C "${KERNEL_DIR}" fetch --quiet github "${BRANCH_DEVICE}" 2>/dev/null || true
    KERNEL_PENDING=0
    if git -C "${KERNEL_DIR}" merge-base "${BRANCH_DEVICE}" "github/${BRANCH_DEVICE}" >/dev/null 2>&1; then
        KERNEL_PENDING=$(git -C "${KERNEL_DIR}" rev-list --count "${BRANCH_DEVICE}..github/${BRANCH_DEVICE}" 2>/dev/null || echo 0)
    fi

    if [ "${KERNEL_PENDING}" -gt 0 ]; then
        CURRENT_KERNEL_BRANCH=$(git -C "${KERNEL_DIR}" branch --show-current 2>/dev/null || true)

        echo "[INFO] Merging ${KERNEL_PENDING} commit(s) into kernel branch '${BRANCH_DEVICE}'..."
        git -C "${KERNEL_DIR}" checkout "${BRANCH_DEVICE}"
        if ! git -C "${KERNEL_DIR}" merge --no-edit "github/${BRANCH_DEVICE}"; then
            echo "[ERROR] Merge collision on ${BRANCH_DEVICE}. Aborting merge."
            git -C "${KERNEL_DIR}" merge --abort
            [ -n "${CURRENT_KERNEL_BRANCH}" ] && git -C "${KERNEL_DIR}" checkout "${CURRENT_KERNEL_BRANCH}" 2>/dev/null || true
            exit 1
        fi

        # Inspect if VFS or security-sensitive hooks differ between sister branches and stock branch
        VFS_TOUCHED=""
        for sister in lineage-21-ksu lineage-21-resukisu; do
            if git -C "${KERNEL_DIR}" rev-parse --verify "${sister}" >/dev/null 2>&1; then
                diff_vfs=$(git -C "${KERNEL_DIR}" diff --name-only "${sister}...${BRANCH_DEVICE}" | grep -E '^(fs/|security/selinux/|kernel/reboot\.c|drivers/kernelsu)' || true)
                if [ -n "${diff_vfs}" ]; then
                    VFS_TOUCHED="${VFS_TOUCHED}${diff_vfs}"$'\n'
                fi
            fi
        done

        MERGE_FAILED=0
        if [ -n "${VFS_TOUCHED}" ]; then
            echo "[WARN] Kernel changes touch VFS/security files against sister branches:"
            echo -e "${VFS_TOUCHED}" | sort -u | sed '/^$/d' | sed 's/^/  * /'
            echo "[WARN] Manual inspection of SuSFS / ReSukiSU hooks required before auto-merging rooted branches."
            MERGE_FAILED=1
        else
            echo "[OK] No VFS conflicts detected. Porting foundation changes to sister branches..."
            for sister in lineage-21-ksu lineage-21-resukisu; do
                if git -C "${KERNEL_DIR}" rev-parse --verify "${sister}" >/dev/null 2>&1; then
                    s_pending=$(git -C "${KERNEL_DIR}" rev-list --count "${sister}..${BRANCH_DEVICE}" 2>/dev/null || echo 0)
                    if [ "${s_pending}" -gt 0 ]; then
                        echo "  -> Updating branch ${sister} (${s_pending} commit(s) behind)..."
                        git -C "${KERNEL_DIR}" checkout "${sister}"
                        if ! git -C "${KERNEL_DIR}" merge --no-edit "${BRANCH_DEVICE}"; then
                            echo "[ERROR] Merge collision on branch ${sister}. Aborting merge."
                            git -C "${KERNEL_DIR}" merge --abort
                            MERGE_FAILED=1
                            break
                        fi
                    fi
                fi
            done
        fi

        # Restore previous branch if set
        [ -n "${CURRENT_KERNEL_BRANCH}" ] && git -C "${KERNEL_DIR}" checkout "${CURRENT_KERNEL_BRANCH}" 2>/dev/null || true

        if [ "${MERGE_FAILED}" -ne 0 ]; then
            echo "[ERROR] Kernel update requires manual resolution. Halting pipeline."
            exit 1
        fi
    else
        echo "[OK] ${KERNEL_DIR} (${BRANCH_DEVICE}) and all sister branches are up to date."
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
