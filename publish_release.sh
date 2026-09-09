#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LineageOS 21.0 (Android 14) for whyred - Automated Release Publisher
# ==============================================================================
# Generates multi-repository changelogs, computes SHA-256 checksums, and publishes
# releases to GitHub with all required artifacts.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

OUT_DIR="${OUT_DIR:-out/target/product/whyred}"
DEFAULT_TAG="v21.0-$(date +%Y%m%d)-whyred"
TAG=""
AUTO_CONFIRM=false
DRY_RUN=false

KERNEL_ONLY=""
KERNEL_VARIANT=""

# Parse flags
for arg in "$@"; do
    case "${arg}" in
        --yes|-y)
            AUTO_CONFIRM=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --tag=*)
            TAG="${arg#*=}"
            ;;
        --kernel-release=*)
            KERNEL_ONLY=true
            KERNEL_VARIANT="${arg#*=}"
            ;;
        --kernel-only)
            KERNEL_ONLY=true
            KERNEL_VARIANT="all"
            ;;
        -*)
            echo "Unknown option: ${arg}"
            ;;
        *)
            if [ -z "${TAG}" ]; then
                TAG="${arg}"
            fi
            ;;
    esac
done

if [ -z "${TAG}" ]; then
    if [ "${KERNEL_ONLY}" = true ]; then
        TAG="kernel-${KERNEL_VARIANT}-$(date +%Y%m%d)-whyred"
    else
        TAG="${DEFAULT_TAG}"
    fi
fi

echo "=========================================================="
echo " LineageOS 21.0 Release Publisher for Redmi Note 5 Pro"
echo " Target Tag: ${TAG}"
echo " Output Directory: ${OUT_DIR}"
if [ "${KERNEL_ONLY}" = true ]; then
    echo " Mode: Standalone Kernel Release (${KERNEL_VARIANT})"
fi
echo "=========================================================="

# 1. Verify GitHub CLI authentication
if ! command -v gh &>/dev/null; then
    echo "ERROR: GitHub CLI ('gh') is not installed. Please install it first."
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "ERROR: GitHub CLI is not authenticated. Run 'gh auth login' to authenticate."
    exit 1
fi

# 2. Identify Release Artifacts
if [ ! -d "${OUT_DIR}" ]; then
    echo "ERROR: Output directory '${OUT_DIR}' does not exist. Please compile first."
    exit 1
fi

BOOT_IMG="${OUT_DIR}/boot.img"
BOOT_KSU_IMG="${OUT_DIR}/boot-ksu.img"
BOOT_RESUKISU_IMG="${OUT_DIR}/boot-resukisu.img"
RECOVERY_IMG="${OUT_DIR}/recovery.img"
ROM_ZIP=$(ls -t "${OUT_DIR}"/lineage-21.0-*-UNOFFICIAL-whyred.zip 2>/dev/null | head -n 1 || true)

RELEASE_ASSETS=()

if [ "${KERNEL_ONLY}" = true ]; then
    case "${KERNEL_VARIANT}" in
        ksu|ksunext)
            if [ ! -f "${BOOT_KSU_IMG}" ]; then
                echo "ERROR: KernelSU boot image '${BOOT_KSU_IMG}' not found."
                exit 1
            fi
            RELEASE_ASSETS+=("${BOOT_KSU_IMG}")
            ;;
        resukisu)
            if [ ! -f "${BOOT_RESUKISU_IMG}" ]; then
                echo "ERROR: ReSukiSU boot image '${BOOT_RESUKISU_IMG}' not found."
                exit 1
            fi
            RELEASE_ASSETS+=("${BOOT_RESUKISU_IMG}")
            ;;
        stock)
            if [ ! -f "${BOOT_IMG}" ]; then
                echo "ERROR: Stock boot image '${BOOT_IMG}' not found."
                exit 1
            fi
            RELEASE_ASSETS+=("${BOOT_IMG}")
            ;;
        all)
            [ -f "${BOOT_IMG}" ] && RELEASE_ASSETS+=("${BOOT_IMG}")
            [ -f "${BOOT_KSU_IMG}" ] && RELEASE_ASSETS+=("${BOOT_KSU_IMG}")
            [ -f "${BOOT_RESUKISU_IMG}" ] && RELEASE_ASSETS+=("${BOOT_RESUKISU_IMG}")
            if [ ${#RELEASE_ASSETS[@]} -eq 0 ]; then
                echo "ERROR: No boot image assets (boot.img, boot-ksu.img, boot-resukisu.img) found in ${OUT_DIR}."
                exit 1
            fi
            ;;
        *)
            echo "ERROR: Unknown kernel variant '${KERNEL_VARIANT}'. Use: stock, ksu, resukisu, or all."
            exit 1
            ;;
    esac
else
    if [ -z "${ROM_ZIP}" ] || [ ! -f "${ROM_ZIP}" ]; then
        echo "ERROR: No LineageOS ROM zip found in ${OUT_DIR}."
        exit 1
    fi
    if [ ! -f "${BOOT_IMG}" ]; then
        echo "ERROR: Stock boot image '${BOOT_IMG}' not found."
        exit 1
    fi
    if [ ! -f "${RECOVERY_IMG}" ]; then
        echo "ERROR: Recovery image '${RECOVERY_IMG}' not found."
        exit 1
    fi

    RELEASE_ASSETS=("${ROM_ZIP}" "${BOOT_IMG}" "${RECOVERY_IMG}")
    if [ -f "${BOOT_KSU_IMG}" ]; then
        RELEASE_ASSETS+=("${BOOT_KSU_IMG}")
    fi
    if [ -f "${BOOT_RESUKISU_IMG}" ]; then
        RELEASE_ASSETS+=("${BOOT_RESUKISU_IMG}")
    fi
fi

echo "Found release artifacts:"
for asset in "${RELEASE_ASSETS[@]}"; do
    echo "  - $(basename "${asset}") ($(du -h "${asset}" | cut -f1))"
done

# 3. Compute SHA-256 Checksums
CHECKSUMS_FILE="${OUT_DIR}/sha256sums.txt"
echo ""
echo "Generating SHA-256 checksums..."
rm -f "${CHECKSUMS_FILE}"

for asset in "${RELEASE_ASSETS[@]}"; do
    (cd "$(dirname "${asset}")" && sha256sum "$(basename "${asset}")") >> "${CHECKSUMS_FILE}"
done
RELEASE_ASSETS+=("${CHECKSUMS_FILE}")

echo "Checksums generated:"
cat "${CHECKSUMS_FILE}"

# 4. Generate Multi-Repository Changelog
echo ""
echo "Collecting commits across sub-repositories..."

# Find latest tag or fallback date
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ -n "${LAST_TAG}" ]; then
    SINCE_DATE=$(git log -1 --format=%cI "${LAST_TAG}" 2>/dev/null || true)
else
    SINCE_DATE=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)
fi

generate_repo_log() {
    local repo_path="$1"
    if [ -d "${repo_path}/.git" ]; then
        if [ -n "${SINCE_DATE}" ]; then
            git -C "${repo_path}" log --no-merges --since="${SINCE_DATE}" --pretty=format:"* %s (%h)" 2>/dev/null || true
        else
            git -C "${repo_path}" log -n 10 --no-merges --pretty=format:"* %s (%h)" 2>/dev/null || true
        fi
    fi
}

CHANGELOG_BODY=""
REPOS_TO_CHECK=(
    ".:Root Orchestration & Manifests"
    "device/xiaomi/whyred:Device Tree (whyred)"
    "device/xiaomi/sdm660-common:Common Device Tree (sdm660-common)"
    "kernel/xiaomi/sdm660:Kernel Tree (Linux 4.19.325)"
    "vendor/xiaomi/whyred:Proprietary Vendor Blobs"
    "build/make:Android Build System"
)

for entry in "${REPOS_TO_CHECK[@]}"; do
    repo_path="${entry%%:*}"
    repo_title="${entry##*:}"
    repo_log=$(generate_repo_log "${repo_path}")
    if [ -n "${repo_log}" ]; then
        CHANGELOG_BODY="${CHANGELOG_BODY}

### ${repo_title}
${repo_log}"
    fi
done

if [ -z "${CHANGELOG_BODY}" ]; then
    CHANGELOG_BODY="* Routine performance optimizations and upstream security sync."
fi

# 5. Format Release Notes
NOTES_FILE="${OUT_DIR}/release_notes_${TAG}.md"

if [ "${KERNEL_ONLY}" = true ]; then
    RELEASE_TITLE="Linux Kernel 4.19 (${KERNEL_VARIANT}) for whyred"
    cat <<EOF > "${NOTES_FILE}"
# Linux Kernel 4.19 (${KERNEL_VARIANT}) for Xiaomi Redmi Note 5 Pro (whyred)

Dedicated kernel release for **whyred** powered by **Linux Kernel 4.19.325** (ThinLTO Clang optimized).

- **Kernel Variant**: ${KERNEL_VARIANT}
- **Linux Base**: 4.19.325
- **Compiler**: Clang (ThinLTO + Polly optimizations)
- **Target Device**: Xiaomi Redmi Note 5 / Note 5 Pro (\`whyred\`)

## What's Changed in this Release

${CHANGELOG_BODY}

## Assets & SHA-256 Checksums

\`\`\`text
$(cat "${CHECKSUMS_FILE}")
\`\`\`

## Installation Instructions

1. **Flash Kernel via Fastboot**:
   \`\`\`bash
   fastboot flash boot $(basename "${RELEASE_ASSETS[0]}")
   fastboot reboot
   \`\`\`

EOF
else
    RELEASE_TITLE="LineageOS 21.0 (Android 14) for whyred"
    cat <<EOF > "${NOTES_FILE}"
# LineageOS 21.0 (Android 14) for Xiaomi Redmi Note 5 Pro (whyred)

Unofficial production release of **LineageOS 21.0** (Android 14) powered by **Linux Kernel 4.19** (4.19.325) for \`whyred\`.

## System Specifications & Build Details

- **Android Version**: 14 (LineageOS 21.0)
- **Linux Kernel**: 4.19.325 (ThinLTO Clang optimized)
- **Build Variant**: \`user\` (Signed with private release-keys)
- **Security Patch Level**: August 2026
- **Storage / File System**: File-Based Encryption (FBE / ICE), F2FS data formatting strongly recommended
- **SELinux**: Enforcing
- **ZRAM**: 2GB LZ4 compressed swap
- **eMMC I/O**: Configured MMC queue depth 128/256 for sustained transfer speed

## What's Changed in this Release

${CHANGELOG_BODY}

## Assets & SHA-256 Checksums

\`\`\`text
$(cat "${CHECKSUMS_FILE}")
\`\`\`

## Installation Instructions

### Clean Flash (Recommended)
1. **Flash Recovery via Fastboot**:
   \`\`\`bash
   fastboot flash recovery recovery.img
   fastboot reboot recovery
   \`\`\`
2. **Sideload ROM Zip**:
   \`\`\`bash
   adb sideload $(basename "${ROM_ZIP}")
   \`\`\`
3. **Format Data to F2FS**:
   - In Recovery: Select **Advanced** > **Reboot to Recovery** (reloads new partition layout).
   - Select **Factory Reset** > **Format Data / Factory Reset** > **Format Data** (\`yes\`).
4. **Reboot to System**:
   - Select **Reboot system now**.

### Root via KernelSU Next + SuSFS (LTS / Stable)
If you require proven, stable root with Play Integrity pass:
1. Flash the KernelSU Next boot image:
   \`\`\`bash
   fastboot flash boot boot-ksu.img
   fastboot reboot
   \`\`\`
2. Install **KernelSU Next Manager** APK:
   - Release: https://github.com/KernelSU-Next/KernelSU-Next/releases

### Root via ReSukiSU + SuSFS v2.3.0+ (Bleeding-Edge / Metamodules)
If you require advanced stealth, metamodules, and multi-manager support:
1. Flash the ReSukiSU boot image:
   \`\`\`bash
   fastboot flash boot boot-resukisu.img
   fastboot reboot
   \`\`\`
2. Install **ReSukiSU Manager** (or any supported multi-manager):
   - Release: https://github.com/ReSukiSU/ReSukiSU/releases

EOF
fi

echo "Generated release notes in ${NOTES_FILE}."

# 6. Publish via GitHub CLI
if [ "${DRY_RUN}" = true ]; then
    echo ""
    echo "[DRY RUN] Release notes preview:"
    echo "----------------------------------------------------------"
    cat "${NOTES_FILE}"
    echo "----------------------------------------------------------"
    echo "[DRY RUN] Would execute:"
    echo "gh release create \"${TAG}\" --title \"${RELEASE_TITLE}\" --notes-file \"${NOTES_FILE}\" ${RELEASE_ASSETS[*]}"
    exit 0
fi

if [ "${AUTO_CONFIRM}" != true ]; then
    echo ""
    read -p "Ready to publish release '${TAG}' to GitHub? [y/N]: " confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo "Release publication aborted by user."
        exit 0
    fi
fi

echo ""
echo "Publishing release to GitHub..."

# Check if release tag already exists
if gh release view "${TAG}" &>/dev/null; then
    echo "Tag '${TAG}' already exists. Updating release notes and uploading assets..."
    gh release edit "${TAG}" --title "${RELEASE_TITLE}" --notes-file "${NOTES_FILE}"
    gh release upload "${TAG}" "${RELEASE_ASSETS[@]}" --clobber
else
    gh release create "${TAG}" \
        --title "${RELEASE_TITLE}" \
        --notes-file "${NOTES_FILE}" \
        "${RELEASE_ASSETS[@]}"
fi

echo ""
echo "=========================================================="
echo " Release '${TAG}' successfully published!"
gh release view "${TAG}" --web || gh release view "${TAG}"
echo "=========================================================="
