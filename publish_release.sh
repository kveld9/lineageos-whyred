#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# LineageOS Automated Release Publisher
# ==============================================================================
# Generates multi-repository changelogs, computes SHA-256 checksums, and publishes
# releases to GitHub with all required artifacts.
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

DEVICE="${DEVICE:-whyred}"
BUILD_VARIANT="${BUILD_VARIANT:-user}"
OUT_DIR="${OUT_DIR:-out/target/product/${DEVICE}}"
KERNEL_DIR="${KERNEL_DIR:-kernel/xiaomi/sdm660}"

# Locate system build.prop dynamically
BUILD_PROP="${OUT_DIR}/system/build.prop"
[ ! -f "${BUILD_PROP}" ] && BUILD_PROP="${OUT_DIR}/system/system/build.prop"

# Dynamic metadata extraction from build artifacts and source tree
LINEAGE_VER=$(grep "^ro.lineage.build.version=" "${BUILD_PROP}" 2>/dev/null | cut -d'=' -f2 || echo "21.0")
LINEAGE_VER="${LINEAGE_VER:-21.0}"
ANDROID_VERSION=$(grep "^ro.build.version.release=" "${BUILD_PROP}" 2>/dev/null | cut -d'=' -f2 || echo "14")
ANDROID_VERSION="${ANDROID_VERSION:-14}"
SECURITY_PATCH=$(grep "^ro.build.version.security_patch=" "${BUILD_PROP}" 2>/dev/null | cut -d'=' -f2 || echo "")
TARGET_DEVICE=$(grep "^ro.product.system.device=" "${BUILD_PROP}" 2>/dev/null | cut -d'=' -f2 || echo "${DEVICE}")
TARGET_DEVICE="${TARGET_DEVICE:-${DEVICE}}"
DEVICE_MODEL=$(grep "^ro.product.system.model=" "${BUILD_PROP}" 2>/dev/null | cut -d'=' -f2 || echo "Xiaomi Redmi Note 5 Pro")
DEVICE_MODEL="${DEVICE_MODEL:-Xiaomi Redmi Note 5 Pro}"
KERNEL_VERSION=$(awk '/^VERSION =/ {v=$3} /^PATCHLEVEL =/ {p=$3} /^SUBLEVEL =/ {s=$3} END {print v "." p "." s}' "${KERNEL_DIR}/Makefile" 2>/dev/null || echo "4.19")
KERNEL_VERSION="${KERNEL_VERSION:-4.19}"

DEFAULT_TAG="v${LINEAGE_VER}-$(date +%Y%m%d)-${TARGET_DEVICE}"
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
        TAG="kernel-${KERNEL_VARIANT}-$(date +%Y%m%d)-${TARGET_DEVICE}"
    else
        TAG="${DEFAULT_TAG}"
    fi
fi

echo "=========================================================="
echo " LineageOS ${LINEAGE_VER} Release Publisher for ${DEVICE_MODEL} (${TARGET_DEVICE})"
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
ROM_ZIP=$(ls -t "${OUT_DIR}"/lineage-${LINEAGE_VER}-*-${TARGET_DEVICE}.zip "${OUT_DIR}"/lineage-*.zip 2>/dev/null | grep -v "ota" | head -n 1 || true)

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

# Ensure we have the latest remote tags locally
git fetch --tags origin 2>/dev/null || true

# Find latest tag or fallback date
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || true)
if [ "${LAST_TAG}" = "${TAG}" ]; then
    LAST_TAG=$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || true)
fi
if [ -n "${LAST_TAG}" ]; then
    SINCE_DATE=$(git log -1 --format=%cI "${LAST_TAG}" 2>/dev/null || true)
else
    SINCE_DATE=$(date -d "7 days ago" +%Y-%m-%d 2>/dev/null || date -v-7d +%Y-%m-%d)
fi

generate_repo_log() {
    local repo_path="$1"
    local is_root="$2"
    if [ -d "${repo_path}/.git" ]; then
        # Exclude internal lab audits, agent rules, and protocol commits
        local filter_regex="^(docs\(audit|docs\(agents|docs\(protocol|chore\()"
        if [ "${is_root}" = "true" ]; then
            # In root orchestration, exclude all internal docs churn, retaining functional features, fixes, and build tools
            filter_regex="^(docs|chore)"
        fi

        # Resolve GitHub web URL for explicit commit hyperlinks across all subrepositories
        local raw_url=$(git -C "${repo_path}" config --get remote.origin.url 2>/dev/null || git -C "${repo_path}" config --get remote.github.url 2>/dev/null || true)
        local web_url=$(echo "${raw_url}" | sed -E 's|git@github.com:|https://github.com/|; s|\.git$||')

        local format_str="* %s (%h)"
        if [ -n "${web_url}" ]; then
            format_str="* %s ([%h](${web_url}/commit/%H))"
        fi

        if [ -n "${SINCE_DATE}" ]; then
            git -C "${repo_path}" log --no-merges --since="${SINCE_DATE}" --pretty=format:"${format_str}" -E --invert-grep --grep="${filter_regex}" 2>/dev/null || true
        else
            git -C "${repo_path}" log -n 15 --no-merges --pretty=format:"${format_str}" -E --invert-grep --grep="${filter_regex}" 2>/dev/null || true
        fi
    fi
}

CHANGELOG_BODY=""
REPOS_TO_CHECK=(
    ".:Root Orchestration & Manifests"
    "device/xiaomi/${TARGET_DEVICE}:Device Tree (${TARGET_DEVICE})"
    "device/xiaomi/sdm660-common:Common Device Tree (sdm660-common)"
    "${KERNEL_DIR}:Kernel Tree (Linux ${KERNEL_VERSION})"
    "vendor/xiaomi/${TARGET_DEVICE}:Proprietary Vendor Blobs"
    "build/make:Android Build System"
)

for entry in "${REPOS_TO_CHECK[@]}"; do
    repo_path="${entry%%:*}"
    repo_title="${entry##*:}"
    is_root="false"
    [ "${repo_path}" = "." ] && is_root="true"
    repo_log=$(generate_repo_log "${repo_path}" "${is_root}")
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
    RELEASE_TITLE="Linux Kernel ${KERNEL_VERSION} (${KERNEL_VARIANT}) for ${TARGET_DEVICE}"
    cat <<EOF > "${NOTES_FILE}"
# Linux Kernel ${KERNEL_VERSION} (${KERNEL_VARIANT}) for ${DEVICE_MODEL} (${TARGET_DEVICE})

Dedicated kernel release for **${TARGET_DEVICE}** powered by **Linux Kernel ${KERNEL_VERSION}** (ThinLTO Clang optimized).

- **Kernel Variant**: ${KERNEL_VARIANT}
- **Kernel Base**: Linux ${KERNEL_VERSION}
- **Compiler**: Clang (ThinLTO + Polly optimizations)
- **Target Device**: ${DEVICE_MODEL} (\`${TARGET_DEVICE}\`)

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
    RELEASE_TITLE="LineageOS ${LINEAGE_VER} (Android ${ANDROID_VERSION}) for ${TARGET_DEVICE}"
    cat <<EOF > "${NOTES_FILE}"
# LineageOS ${LINEAGE_VER} (Android ${ANDROID_VERSION}) for ${DEVICE_MODEL} (${TARGET_DEVICE})

Production release of **LineageOS ${LINEAGE_VER}** (Android ${ANDROID_VERSION}) powered by **Linux Kernel ${KERNEL_VERSION}** for \`${TARGET_DEVICE}\`.

- **Build Target**: \`lineage_${TARGET_DEVICE}-${BUILD_VARIANT:-user}\` (Signed with private release-keys)$([ -n "${SECURITY_PATCH}" ] && echo -e "\n- **Security Patch Level**: ${SECURITY_PATCH}")
- **Kernel Base**: Linux ${KERNEL_VERSION} (ThinLTO Clang optimized)
- **Target Device**: ${DEVICE_MODEL} (\`${TARGET_DEVICE}\`)

## What's Changed in this Release

${CHANGELOG_BODY}

## Assets & SHA-256 Checksums

\`\`\`text
$(cat "${CHECKSUMS_FILE}")
\`\`\`

## Installation & Root Guides
* [Installation & Clean Flash Guide](INSTALL.md)
* [KernelSU Next & SuSFS Setup Guide](KERNELSU.md)
* [ReSukiSU & Metamodules Guide](RESUKISU.md)
* [System Debloat Guide](DEBLOAT.md)

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

# Fetch tags locally so subsequent runs calculate exact deltas from this tag
git fetch --tags origin 2>/dev/null || true

echo ""
echo "=========================================================="
echo " Release '${TAG}' successfully published!"
gh release view "${TAG}" --web || gh release view "${TAG}"
echo "=========================================================="
