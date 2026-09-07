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

# Setup build environment
source build/envsetup.sh

# Configure target device
breakfast whyred

echo ""
echo "=========================================================="
echo " Environment is ready!"
echo " To start compiling LineageOS 21 (Android 14) for whyred, run:"
echo "   brunch whyred"
echo " or:"
echo "   mka bacon"
echo "=========================================================="
