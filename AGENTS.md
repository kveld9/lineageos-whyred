# Autonomous Engineering & Repository Tracking Protocol

## 1. Core Mandate
All modifications, fixes, and configuration changes across this project and its sub-repositories must be tracked, committed atomically, and immediately pushed to remote Git repositories.
- **Commit Immediately**: No uncommitted modifications should remain in the working tree once verified.
- **Push Immediately**: Every committed change must be pushed to its corresponding remote (`origin`) in the root repository or respective personal fork (`kveld9/*`).

## 2. Commit & Push Standards
- **Conventional Commits**: Every commit must strictly follow Conventional Commits specification (e.g., `fix(kernel): ...`, `build(soong): ...`, `fix(device): ...`, `chore(manifest): ...`, `docs: ...`).
- **Language**: All commit messages, documentation, code comments, and technical artifacts must be written in English.
- **No AI Attribution**: Never include `Co-Authored-By`, assistant identifiers, or any AI generation disclosures in commit messages, pull requests, or repository metadata.
- **Atomic Commits**: Separate commits strictly by concern and sub-repository. Do not mix kernel driver fixes with device tree changes or root scripts.
- **Branch Synchronization**: Push to the active tracking branch (`main` for root, `lineage-21` for forks and device trees). If a modified repository lacks a personal remote, fork it to `kveld9`, set the remote, and push.

## 3. Repository Topology & Remote Mapping
This project comprises the root orchestration repository and device-specific trees linked to user forks:
- **Root Repository** (`.`):
  - Remote: `git@github.com:kveld9/lineageos-whyred.git` (`main`)
  - Scope: Orchestration scripts (`build_whyred.sh`), documentation (`README.md`, `AGENTS.md`), local manifests (`local_manifests/`), and editor settings (`.vscode/`).
- **Device Tree** (`device/xiaomi/whyred`):
  - Remote: `git@github.com:kveld9/android_device_xiaomi_whyred.git` (`lineage-21`)
  - Scope: Device-specific makefiles, overlays, permissions, and device configs.
- **Vendor Tree** (`vendor/xiaomi/whyred`):
  - Remote: `git@github.com:kveld9/proprietary_vendor_xiaomi_whyred.git` (`lineage-21`)
  - Scope: Proprietary blobs, vendor configurations, and module inclusions.
- **Kernel Tree** (`kernel/xiaomi/sdm660`):
  - Remote: `git@github.com:kveld9/android_kernel_xiaomi_sdm660.git` (`lineage-21`)
  - Scope: Linux kernel 4.19 source, defconfigs, drivers, and device tree source (DTS).
- **Common Device Tree** (`device/xiaomi/sdm660-common`):
  - Shared SDM660 HAL definitions and configs.
- **Build System** (`build/make`):
  - Remote: `git@github.com:kveld9/android_build.git` (`lineage-21.0`)
  - Scope: Core build system logic, target packaging rules, and release tools.
- **Build Core Tools** (`build/blueprint`, `build/soong`):
  - Build graph generation, bootstrap configurations, and compilation tools.

## 4. Build Continuity & Autonomous Fixes
When tasked with compilation:
1. Autonomously diagnose build failures from build logs.
2. Apply minimal reproducible fixes in the proper sub-tree.
3. Commit each fix with a Conventional Commit in English in that sub-repo.
4. Push the commit to its corresponding GitHub remote immediately.
5. Resume compilation until the target artifact (`m bacon` ROM zip) is 100% completed.

## 5. Documentation & README Maintenance
- **Keep README Updated**: Whenever changes occur to repository topology, fork remotes, build procedures, patch levels, partition layouts, or release artifacts, the agent must immediately update `README.md` to keep documentation accurate, complete, and synchronized with the actual codebase state.
- **Continuous Synchronization**: Documentation updates must be committed with Conventional Commits (e.g., `docs: update README with ...`) and pushed to the remote repository.
