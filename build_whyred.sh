#!/usr/bin/env bash
set -e

# Change to lineage directory
cd "$(dirname "$0")"

# Target configuration (dynamic with variable override)
DEVICE="${DEVICE:-whyred}"
BUILD_VARIANT="${BUILD_VARIANT:-user}"

# Configure CCACHE for faster builds
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)
export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
CCACHE_SIZE="${CCACHE_SIZE:-50G}"
if [ -n "${CCACHE_EXEC}" ]; then
    "${CCACHE_EXEC}" -M "${CCACHE_SIZE}" >/dev/null 2>&1 || true
fi

# Memory & Concurrency constraints (adaptive to host resources)
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

# Ensure cryptographic release keys exist
mkdir -p certs
SUBJECT="${CERT_SUBJECT:-/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com}"
for key in releasekey platform shared media networkstack bluetooth sdk_sandbox nfc testkey; do
    if [ ! -f "certs/${key}.pk8" ] || [ ! -f "certs/${key}.x509.pem" ]; then
        echo "Generating cryptographic key in certs/${key}..."
        openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out "certs/${key}.pk8" -outform DER 2>/dev/null
        openssl req -new -x509 -key <(openssl pkcs8 -inform DER -in "certs/${key}.pk8" -nocrypt) \
            -out "certs/${key}.x509.pem" -days 10000 -subj "${SUBJECT}" 2>/dev/null
        chmod 0600 "certs/${key}.pk8"
        chmod 0644 "certs/${key}.x509.pem"
    fi
done

# Setup build environment
source build/envsetup.sh

# Configure target device dynamically
breakfast "${DEVICE}" "${BUILD_VARIANT}"

ACTION="${1:-help}"

case "${ACTION}" in
    --build)
        echo "Starting LineageOS ROM build (${DEVICE}-${BUILD_VARIANT})..."
        mka bacon
        ;;
    --build-ksu)
        echo "Building dedicated KernelSU boot image..."
        ./build_ksu_boot.sh
        ;;
    --build-resukisu)
        echo "Building dedicated ReSukiSU boot image..."
        ./build_resukisu_boot.sh
        ;;
    --publish)
        shift 1 || true
        ./publish_release.sh "$@"
        ;;
    --all)
        echo "=========================================================="
        echo " Full Automated Pipeline: ROM -> 3 Kernels -> Release"
        echo "=========================================================="
        shift 1 || true
        echo "[1/4] Building clean LineageOS ROM (${DEVICE}-${BUILD_VARIANT})..."
        mka bacon
        echo "[2/4] Building KernelSU Next + SuSFS boot image..."
        ./build_ksu_boot.sh
        echo "[3/4] Building ReSukiSU + SuSFS boot image..."
        ./build_resukisu_boot.sh
        echo "[4/4] Generating changelogs, checksums & publishing release..."
        ./publish_release.sh --yes "$@"
        ;;
    *)
        echo ""
        echo "=========================================================="
        echo " Environment is ready for LineageOS (${DEVICE}) ${BUILD_VARIANT} release!"
        echo " Target: lineage_${DEVICE}-${BUILD_VARIANT} (signed with private release-keys)"
        echo " Host Resources: ${GOMAXPROCS} cores, GOMEMLIMIT=${GOMEMLIMIT}"
        echo ""
        echo " Available options:"
        echo "   mka bacon                           (Compile ROM manually)"
        echo "   ./build_whyred.sh --build           (Run mka bacon)"
        echo "   ./build_whyred.sh --build-ksu       (Build boot-ksu.img)"
        echo "   ./build_whyred.sh --build-resukisu  (Build boot-resukisu.img)"
        echo "   ./build_whyred.sh --publish         (Publish release to GitHub)"
        echo "   ./build_whyred.sh --all             (Build ROM + 3 Kernels + Auto-publish)"
        echo "=========================================================="
        ;;
esac

