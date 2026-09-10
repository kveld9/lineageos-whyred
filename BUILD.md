# Building LineageOS 21.0 from Source

Complete guide for setting up the build environment, synchronizing AOSP and device source trees, and executing automated build pipelines for the Xiaomi Redmi Note 5 Pro (`whyred`).

---

## Hardware and System Requirements

Compiling Android 14 (LineageOS 21.0) requires significant computing and storage resources:

* **Operating System:** Linux host (Arch Linux, Debian 12+, Ubuntu 22.04+ LTS).
* **CPU:** 8 or more physical cores recommended (x86_64 architecture).
* **RAM:** 32 GB RAM recommended (16 GB minimum with a dedicated 16 GB+ swapfile).
* **Storage:** 300 GB or more of free disk space (NVMe SSD strongly recommended for reasonable I/O throughput).

---

## Host Environment & Dependencies

### 1. Install Required Build Packages

#### On Arch Linux:
```bash
sudo pacman -S --needed \
    base-devel git git-lfs repo ccache openssl rsync curl \
    python python-pip libxslt zip unzip bc libelf lz4
```

#### On Debian / Ubuntu:
```bash
sudo apt update && sudo apt install -y \
    build-essential git git-lfs ccache openssl rsync curl \
    python3 python3-pip libxml2-utils zip unzip bc libelf-dev lz4
```

### 2. Configure `ccache` (Recommended)
Compiler caching accelerates subsequent builds from hours to minutes:
```bash
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
ccache -M 50G
```

---

## Source Tree Synchronization

### 1. Clone the Orchestration Repository
```bash
git clone https://github.com/kveld9/lineageos-whyred.git
cd lineageos-whyred
```

### 2. Initialize LineageOS 21.0 Base Repo
```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-21.0 --git-lfs
```

### 3. Install Local Manifest
The local manifest maps the required device tree, vendor blobs, kernel source, and common HAL repositories to their tracked forks:
```bash
mkdir -p .repo/local_manifests
cp local_manifests/whyred.xml .repo/local_manifests/whyred.xml
```

### 4. Synchronize Sources
```bash
repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune -j$(nproc)
```

---

## Cryptographic Release Keys

Release builds require cryptographic signing keys (`releasekey`, `platform`, `shared`, `media`, `networkstack`, `bluetooth`, `sdk_sandbox`, `nfc`, `testkey`).

The automated build script automatically generates a private, unique set of RSA 2048-bit keys under `certs/` on its first run if the directory does not exist:
* The `certs/` directory is ignored by Git (`.gitignore`) and keys are kept strictly local.
* Builds generated on different host machines maintain isolated cryptographic identities.

---

## Automated Compilation Pipelines (`build_whyred.sh`)

The repository provides a unified build automation script: [`build_whyred.sh`](build_whyred.sh).

### 1. Compile Full ROM Package Only
Compiles the LineageOS 21.0 flashable zip signed with private release keys:
```bash
./build_whyred.sh --build
# Equivalent to running: source build/envsetup.sh && breakfast whyred user && mka bacon
```

### 2. Compile KernelSU Next + SuSFS Boot Image Only
Compiles the dedicated kernel variant (`lineage-21-ksu`) with KernelSU Next and SuSFS hooks de-inlined, generating `boot-ksu.img`:
```bash
./build_ksu_boot.sh
# Or via main script:
./build_whyred.sh --build-ksu
```

### 3. Publish Release to GitHub
Uploads the compiled artifacts to GitHub Releases with generated changelogs and SHA-256 checksums:
```bash
# Preview actions without uploading
./publish_release.sh --dry-run

# Upload release
./publish_release.sh
```

### 4. Full End-to-End Pipeline
Executes the full chain sequentially: ROM compilation &rarr; KernelSU Next boot compilation &rarr; ReSukiSU boot compilation &rarr; Checksum generation &rarr; GitHub Release:
```bash
./build_whyred.sh --all
```

---

## Generated Output Artifacts

All built images and flashable packages are output to `out/target/product/whyred/`:

| Output File | Description |
| :--- | :--- |
| `lineage-21.0-*-UNOFFICIAL-whyred.zip` | Full flashable ROM zip signed with private release keys |
| `boot.img` | Stock clean Linux 4.19.325 kernel image and initramfs |
| `boot-ksu.img` | KernelSU Next v3.1.0-legacy-susfs + SuSFS v2.0.0 kernel image |
| `recovery.img` | Standalone LineageOS 21.0 recovery image |
| `sha256sums.txt` | Cryptographic SHA-256 digests for all release files |

---

## Related Documentation

* [Main Project Documentation](README.md)
* [Installation and Flashing Guide](INSTALL.md)
* [KernelSU Next & SuSFS Setup Guide](KERNELSU.md)
* [System Debloating Guide](DEBLOAT.md)
* [Kernel & Hardware Audit Registry](AUDIT_REGISTRY.md)
