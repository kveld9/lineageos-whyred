#!/usr/bin/env bash
set -e

# Change to lineage directory
cd "$(dirname "$0")"

# Configure CCACHE for faster builds
export USE_CCACHE=1
export CCACHE_EXEC=$(which ccache)
export CCACHE_DIR="${HOME}/.ccache"
ccache -M 50G

# Memory & Concurrency constraints to prevent OOM
export GOMEMLIMIT=16GiB
export GOMAXPROCS=8

# Ensure cryptographic release keys exist
if [ ! -f "certs/releasekey.pk8" ]; then
    echo "Generating private cryptographic release keys in certs/..."
    mkdir -p certs
    SUBJECT="/C=US/ST=California/L=Mountain View/O=Android/OU=Android/CN=Android/emailAddress=android@android.com"
    for key in releasekey platform shared media networkstack bluetooth sdk_sandbox nfc; do
        if [ ! -f "certs/${key}.pk8" ]; then
            openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out "certs/${key}.pk8" -outform DER 2>/dev/null
            openssl req -new -x509 -key <(openssl pkcs8 -inform DER -in "certs/${key}.pk8" -nocrypt) \
                -out "certs/${key}.x509.pem" -days 10000 -subj "${SUBJECT}" 2>/dev/null
        fi
    done
    chmod 0600 certs/*.pk8
    chmod 0644 certs/*.x509.pem
fi

# Setup build environment
source build/envsetup.sh

# Configure target device as a stable user release
breakfast whyred user

echo ""
echo "=========================================================="
echo " Environment is ready for LineageOS 21 (Android 14) user release!"
echo " Target: lineage_whyred-user (signed with private release-keys)"
echo " To start compiling, run:"
echo "   mka bacon"
echo "=========================================================="

