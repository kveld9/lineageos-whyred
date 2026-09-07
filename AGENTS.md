# Autonomous Engineering & Repository Tracking Protocol

## 1. Core Mandate
All modifications, fixes, and configuration changes across this project and its sub-repositories must be tracked and committed atomically in Git. No uncommitted modifications should remain in the working tree once verified.

## 2. Commit Standards
- **Conventional Commits**: Every commit must strictly follow Conventional Commits specification (e.g., `fix(kernel): ...`, `build(soong): ...`, `fix(device): ...`).
- **Language**: All commit messages, documentation, and technical artifacts must be written in English.
- **No AI Attribution**: Never include `Co-Authored-By`, assistant identifiers, or any AI generation disclosures in commit messages or repository metadata.
- **Atomic Commits**: Separate commits by concern and sub-repository. Do not mix kernel driver fixes with device tree changes or root scripts.

## 3. Repository Topology
This project comprises the Android build system and device-specific trees:
- **Root Repository** (`.`): Contains orchestration scripts (`build_whyred.sh`), project documentation (`CONTEXT.md`, `AGENTS.md`), and editor configurations (`.vscode/`).
- **Device Tree** (`device/xiaomi/whyred`): Device-specific makefiles, overlays, and permissions.
- **Vendor Tree** (`vendor/xiaomi/whyred`): Proprietary blobs, vendor configurations, and module inclusions.
- **Kernel Tree** (`kernel/xiaomi/sdm660`): Linux kernel 4.19 source, defconfigs, and hardware drivers.
- **Common Device Tree** (`device/xiaomi/sdm660-common`): Shared SDM660 HAL definitions and configs.
- **Build System** (`build/blueprint`, `build/soong`): Build graph generation and compilation tools.

## 4. Build Continuity
When tasked with compilation, autonomously diagnose failures, apply minimal reproducible fixes, commit them to the respective repository with clear explanations, and resume compilation until completion.
