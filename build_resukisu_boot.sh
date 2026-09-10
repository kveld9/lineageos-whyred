#!/usr/bin/env bash
set -eo pipefail

# ==============================================================================
# LineageOS - Dedicated ReSukiSU + SuSFS Boot Image Builder
# ==============================================================================
# Checks out the isolated lineage-21-resukisu kernel branch, compiles bootimage,
# saves boot-resukisu.img in target output directory, and safely restores stock branch.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

DEVICE="${DEVICE:-whyred}"
BUILD_VARIANT="${BUILD_VARIANT:-user}"
KERNEL_DIR="${KERNEL_DIR:-kernel/xiaomi/sdm660}"
OUT_DIR="${OUT_DIR:-out/target/product/${DEVICE}}"
RESUKISU_BRANCH="${RESUKISU_BRANCH:-lineage-21-resukisu}"

echo "=========================================================="
echo " Building ReSukiSU + SuSFS Boot Image for ${DEVICE}"
echo "=========================================================="

if [ ! -d "${KERNEL_DIR}" ]; then
    echo "ERROR: Kernel directory '${KERNEL_DIR}' not found."
    exit 1
fi

CURRENT_BRANCH=$(git -C "${KERNEL_DIR}" branch --show-current 2>/dev/null || true)
CURRENT_BRANCH="${CURRENT_BRANCH:-lineage-21}"
echo "Current kernel branch: ${CURRENT_BRANCH}"

# Ensure ccache and resource limits
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)
export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
CCACHE_SIZE="${CCACHE_SIZE:-50G}"
if [ -n "${CCACHE_EXEC}" ]; then
    "${CCACHE_EXEC}" -M "${CCACHE_SIZE}" >/dev/null 2>&1 || true
fi

if [ -z "${GOMEMLIMIT:-}" ]; then
    total_mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || true)
    total_mem_kb="${total_mem_kb:-0}"
    if [ "${total_mem_kb}" -gt 0 ]; then
        limit_mib=$(( total_mem_kb * 75 / 100 / 1024 ))
        export GOMEMLIMIT="${limit_mib}MiB"
    else
        export GOMEMLIMIT="16GiB"
    fi
fi
export GOMAXPROCS="${GOMAXPROCS:-$(nproc 2>/dev/null || echo 8)}"

# Backup stock boot.img if present
if [ -f "${OUT_DIR}/boot.img" ]; then
    echo "Backing up stock boot.img to boot-stock.img..."
    cp -f "${OUT_DIR}/boot.img" "${OUT_DIR}/boot-stock.img"
fi

# Clean prior kernel binary and intermediate config to force fresh compilation of ReSukiSU kernel
rm -rf "${OUT_DIR}/obj/KERNEL_OBJ" "${OUT_DIR}/kernel" "${OUT_DIR}/boot.img"

# Guarantee safe return to original branch and restore stock boot.img on exit
cleanup() {
    local exit_code=$?
    echo "Restoring kernel tree to '${CURRENT_BRANCH}'..."
    git -C "${KERNEL_DIR}" checkout "${CURRENT_BRANCH}" >/dev/null 2>&1 || true
    if [ -f "${OUT_DIR}/boot-stock.img" ]; then
        cp -f "${OUT_DIR}/boot-stock.img" "${OUT_DIR}/boot.img"
        rm -f "${OUT_DIR}/boot-stock.img"
    fi
    exit ${exit_code}
}
trap cleanup EXIT INT TERM

echo "Switching kernel tree to '${RESUKISU_BRANCH}'..."
git -C "${KERNEL_DIR}" checkout "${RESUKISU_BRANCH}"

# Ensure build environment
source build/envsetup.sh
breakfast "${DEVICE}" "${BUILD_VARIANT}"

echo "Compiling bootimage (ReSukiSU + SuSFS)..."
mka bootimage

if [ -f "${OUT_DIR}/boot.img" ]; then
    cp -v "${OUT_DIR}/boot.img" "${OUT_DIR}/boot-resukisu.img"
    STRIPPED_WLAN=$(find "${OUT_DIR}/obj/PACKAGING/kernel_modules_intermediates" -name "wlan.ko" 2>/dev/null | head -n 1)
    if [ -n "${STRIPPED_WLAN}" ] && [ -f "${STRIPPED_WLAN}" ]; then
        mkdir -p "${OUT_DIR}/vendor/lib/modules"
        cp -vf "${STRIPPED_WLAN}" "${OUT_DIR}/vendor/lib/modules/wlan.ko"
        echo "Updated ${OUT_DIR}/vendor/lib/modules/wlan.ko (stripped, $(ls -lh "${OUT_DIR}/vendor/lib/modules/wlan.ko" | awk '{print $5}'))"
    elif [ -f "${OUT_DIR}/obj/KERNEL_OBJ/drivers/staging/qcacld-3.0/wlan.ko" ]; then
        mkdir -p "${OUT_DIR}/vendor/lib/modules"
        cp -vf "${OUT_DIR}/obj/KERNEL_OBJ/drivers/staging/qcacld-3.0/wlan.ko" "${OUT_DIR}/vendor/lib/modules/wlan.ko"
        echo "Updated ${OUT_DIR}/vendor/lib/modules/wlan.ko"
    fi
    echo "=========================================================="
    echo " Successfully generated: ${OUT_DIR}/boot-resukisu.img"
    echo " SHA-256: $(sha256sum "${OUT_DIR}/boot-resukisu.img" | cut -d' ' -f1)"
    echo "=========================================================="
else
    echo "ERROR: ${OUT_DIR}/boot.img was not generated."
    exit 1
fi
