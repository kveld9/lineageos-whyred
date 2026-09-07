#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LineageOS 21.0 - Dedicated KernelSU Next + SuSFS Boot Image Builder
# ==============================================================================
# Checks out the isolated lineage-21-ksu kernel branch, compiles bootimage,
# saves out/target/product/whyred/boot-ksu.img, and safely restores stock branch.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

KERNEL_DIR="kernel/xiaomi/sdm660"
OUT_DIR="${OUT_DIR:-out/target/product/whyred}"

echo "=========================================================="
echo " Building KernelSU Next + SuSFS Boot Image for whyred"
echo "=========================================================="

if [ ! -d "${KERNEL_DIR}" ]; then
    echo "ERROR: Kernel directory '${KERNEL_DIR}' not found."
    exit 1
fi

CURRENT_BRANCH=$(git -C "${KERNEL_DIR}" branch --show-current)
echo "Current kernel branch: ${CURRENT_BRANCH}"

# Guarantee safe return to original branch on exit
cleanup() {
    local exit_code=$?
    echo "Restoring kernel tree to '${CURRENT_BRANCH}'..."
    git -C "${KERNEL_DIR}" checkout "${CURRENT_BRANCH}" >/dev/null 2>&1 || true
    exit ${exit_code}
}
trap cleanup EXIT INT TERM

echo "Switching kernel tree to 'lineage-21-ksu'..."
git -C "${KERNEL_DIR}" checkout lineage-21-ksu

# Ensure build environment
source build/envsetup.sh
breakfast whyred user

echo "Compiling bootimage (KernelSU + SuSFS)..."
mka bootimage

if [ -f "${OUT_DIR}/boot.img" ]; then
    cp -v "${OUT_DIR}/boot.img" "${OUT_DIR}/boot-ksu.img"
    echo "=========================================================="
    echo " Successfully generated: ${OUT_DIR}/boot-ksu.img"
    echo " SHA-256: $(sha256sum "${OUT_DIR}/boot-ksu.img" | cut -d' ' -f1)"
    echo "=========================================================="
else
    echo "ERROR: ${OUT_DIR}/boot.img was not generated."
    exit 1
fi
