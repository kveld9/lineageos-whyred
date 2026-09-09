# Autonomous Engineering & Repository Tracking Protocol

## 1. Operational Pipeline
Every authorized modification or fix must strictly execute through the following operational pipeline:
**Scope Lock → State Inspection → Risk Gate → Minimal Change → Validation → Cross-Variant Gate (Kernel) → Atomic Commit → Push Verification → Documentation Sync**

---

## 2. Scope Lock
Before modifying any file across the codebase:
- Identify the explicit user-requested objective.
- Identify target repositories, affected components, and files.
- Formulate the expected behavioral change.
- **Do not expand scope opportunistically**: If an adjacent defect or cleanup opportunity is discovered:
  - Record the defect.
  - Do not fix it in the current atomic unit.
  - Continue only if the user explicitly authorizes expanding scope.

---

## 3. Working Tree & State Inspection
- **Inspect Before Modifying**: Run `git status` in target repositories to identify pre-existing working tree state before touching any file.
- **Protect Pre-existing Changes**: Never modify, reset, revert, stash, amend, or commit changes that were not created by the current task unless explicitly authorized.
- **Verified Changes Discipline**: No verified change may remain uncommitted. Never discard, reset, stash, or overwrite unrelated user changes. Unverified experimental modifications must remain isolated.

---

## 4. Risk Gate & Prohibited Operations
Require explicit user authorization before:
- Deleting source files.
- Adding, changing, or deleting Git repository remotes.
- Switching branches or altering tracking branches.
- Force-pushing (`git push -f`) or rewriting Git history.
- Modifying proprietary blobs in vendor trees.
- Altering partition layouts, block sizes, or storage mount points.
- Modifying release signing configurations or cryptographic keys.
- Changing boot, recovery, or vendor HAL interfaces.
- Modifying security-sensitive kernel configurations, drivers, or SELinux policies.
- Performing destructive repository cleanup.
- Initiating any compilation process when not explicitly authorized.

### Strict Prohibition on Destructive Git Commands
Never run any of the following commands without explicit user authorization:
- `git reset --hard`
- `git clean -fdx` (or any destructive clean in an Android / LineageOS tree)
- `git checkout -- <files>`
- `git restore <files>`
- `git rebase`
- `git commit --amend`

---

## 5. Source Tree vs Generated Artifacts (`out/`)
- **`out/` is Not Source-of-Truth**: Generated build outputs under `out/` are ephemeral artifacts and must never be committed or treated as the source of truth.
- **Never Patch Generated Files**: Do not modify generated files (e.g., generated `.config`, `autoconf.h`, Soong/Ninja intermediaries, or unpacked ramdisks) to fix source-level issues. Trace every defect back to its original source or configuration file.

---

## 6. Kernel & Device Tree Separation
- **Kernel Isolation**: Linux kernel 4.19 driver, subsystem, defconfig, and core architecture changes belong exclusively to `kernel/xiaomi/sdm660`.
- **DTS Classification**: Device-specific Device Tree Source (DTS) modifications must be classified carefully before editing (kernel DTS in `kernel/xiaomi/sdm660/arch/arm64/boot/dts/` vs device tree configurations in `device/xiaomi/whyred`).
- **No Duplicate Fixes**: Never duplicate a fix across kernel and device trees without concrete evidence that both require independent changes.
- **Multi-Variant Kernel Parity & Cross-Variant Fix Protocol**:
  - The kernel tree (`kernel/xiaomi/sdm660`) maintains parallel production variants:
    - `lineage-21`: Canonical stock LineageOS 21 Linux 4.19 kernel.
    - `lineage-21-ksu`: KernelSU-Next and SuSFS integration line.
    - Additional authorized dedicated variants (e.g., `lineage-21-resukisu`).
  - **Shared Foundation Principle**: Kernel variants share a common hardware foundation: Qualcomm/Xiaomi drivers, architecture, core subsystems, hardware DTS, power, audio, camera, and base platform configurations. Variance across branches must strictly reflect explicitly scoped variant-specific deltas (e.g., KSU/SuSFS/ReSukiSU patchsets and their required integration hooks).
  - **Cross-Variant Verification Gate**:
    - Whenever a bug, stability defect, build failure, driver issue, or configuration omission is investigated or fixed on ANY kernel variant touching a potentially shared surface:
      1. **Identify Shared Surface**: Determine if the affected file, subsystem, driver, DTS, or configuration belongs to the shared platform foundation rather than variant-specific logic.
      2. **Audit Active Sister Variants**: Before considering the task or fix unit closed, inspect all active sister variant branches to determine whether the same issue exists or applies.
      3. **Formal Classification**: Each active sister variant must be audited and classified into one of the following states:
         - `FIXED`: Fix ported and verified on the variant within the same operational unit.
         - `ALREADY-FIXED`: Defect was already resolved in the variant or its common ancestor.
         - `EQUIVALENT`: Functionally identical fix already exists under different architecture/hash.
         - `NOT-AFFECTED`: The defect does not apply due to architectural differences (e.g., absent feature or variant-specific prerequisite).
         - `CONFLICTING`: The fix collides with variant-specific code (e.g., VFS hooks) and requires custom semantic adaptation.
         - `PENDING`: Fix evaluation or physical testing is blocked, requiring explicit tracking in `AUDIT_REGISTRY.md`.
    - **No Blind Cherry-Picks**: Cross-variant ports must be evaluated semantically. Never execute an automatic or uninspected `git cherry-pick` without verifying surrounding context, especially in files containing variant hooks (`fs/namei.c`, `fs/namespace.c`, `fs/exec.c`, etc.).
    - **Variant-Specific Fix Isolation**:
      - Fixes strictly internal to a variant (e.g., KernelSU hook adaptation, SuSFS C90 compliance, supercall definitions) must be explicitly scoped (e.g., `fix(ksu): ...`, `fix(susfs): ...`) and must NEVER be propagated to stock or unrelated variants.
    - **Targeted Documentation**:
      - Document cross-variant classification in `AUDIT_REGISTRY.md` or the commit message whenever a fix touches a shared platform surface. Commits strictly internal to variant-specific logic do not require cross-variant documentation.

---

## 7. Compilation Protection & Failure Protocol
- **Strict Prohibition on Unauthorized Builds**: Never initiate or trigger any compilation process (`mka`, `m bootimage`, `m bacon`, kernel builds, or script-driven builds) unless the user explicitly and directly commands or approves compilation.
- **Indirect Compilation Guard**: Compilation includes any command that may invoke Soong, Ninja, Make, Gradle, Kati, or kernel build systems indirectly. Do not run build scripts merely to inspect their behavior or configuration.
- **Build Failure Handling**: When compilation is explicitly authorized:
  1. Autonomously diagnose build failures from logs.
  2. Apply minimal reproducible fixes in the proper sub-tree.
  3. Continue through recoverable, deterministic failures.
  4. **Avoid Infinite Loops**: Immediately stop and report if a failure is external (toolchain corruption, network failure, missing proprietary blob, disk space/quota exhaustion), non-deterministic, introduces destructive risk, or requires a design decision outside the repository.

---

## 8. Commit & Push Standards
- **Conventional Commits**: Every commit must strictly follow Conventional Commits specification in English (e.g., `fix(kernel): ...`, `build(soong): ...`, `fix(device): ...`, `chore(manifest): ...`, `docs: ...`).
- **No AI Attribution**: Never include `Co-Authored-By`, assistant identifiers, or any AI generation disclosures in commit messages, pull requests, or repository metadata.
- **Atomic Commits**: Separate commits strictly by concern and sub-repository. Never combine kernel driver changes with device tree or root orchestration changes.
- **Pre-Commit Inspection (No Blind Commits)**:
  Before committing:
  1. Run `git status`.
  2. Inspect the complete staged diff (`git diff --staged`).
  3. Verify that only intended files are staged.
  4. Run non-compilation validation (syntax checks, lints) when available.
  5. Commit only when the staged diff matches the intended task unit.
- **Push Verification**:
  Before pushing:
  - Verify current branch (`git branch --show-current`).
  - Verify remote URL (`git remote -v`).
  - Verify tracking upstream branch.
  - Check latest commit (`git log -1 --oneline`).
  - Push only to the verified tracking branch (`main` for root, `lineage-21` / `lineage-21-ksu` for trees).
- **Missing Remote Protocol**:
  If a modified repository lacks the required personal remote (`kveld9/*`):
  - Stop before pushing.
  - Report the missing remote to the user.
  - Request authorization before creating or changing repository remotes.

---

## 8.1 Remote Branch Hygiene

Personal fork repositories (`kveld9/*`) must keep only branches that represent an active development line or intentionally preserved work.

Obsolete or abandoned remote branches may be removed only after a verification pass confirms that they contain no pending or uniquely preserved work.

Before deleting any remote branch:

1. Fetch and prune remote references.
2. Verify the current branch topology and tracking relationships.
3. Compare the candidate branch against its corresponding active maintenance branch.
4. Identify commits present only on the candidate branch.
5. Confirm that no unique commit contains pending fixes, experiments, recovery points, or other work that must be preserved.
6. Confirm that relevant work is already merged, cherry-picked, superseded, tagged, or otherwise safely preserved.
7. Obtain explicit user authorization before performing the destructive deletion.
8. Delete only the specifically approved obsolete branch.
9. Verify that the remote branch was actually removed and that no unintended refs were affected.

Branches must **not** be deleted merely because they are old, inactive, or no longer checked out locally. Age or inactivity alone is insufficient justification.

The active maintenance branch for each repository must always be preserved unless the user explicitly authorizes a maintenance-branch migration.

Never perform bulk remote branch deletion without first generating and reviewing a branch/commit inventory.

Branch cleanup must not modify, reset, rewrite, or otherwise alter commit history. Deleting a remote branch is a reference cleanup operation and must not be used as a substitute for normal commit, merge, tag, or archival procedures.

When branch cleanup is performed, document:

* branches inspected;
* branches retained and the reason for retention;
* branches approved for deletion;
* branches actually deleted;
* unique commits found on deleted branches;
* any branches requiring manual review.

If a branch contains work whose preservation status cannot be established with confidence, **do not delete it**. Report it for manual review instead.

---

## 9. Repository Topology & Remote Mapping
- **Root Repository** (`.`):
  - Remote: `git@github.com:kveld9/lineageos-whyred.git` (`main`)
  - Scope: Orchestration scripts (`build_whyred.sh`, `publish_release.sh`), documentation (`README.md`, `AGENTS.md`), local manifests (`local_manifests/`), and editor configs.
- **Device Tree** (`device/xiaomi/whyred`):
  - Remote: `git@github.com:kveld9/android_device_xiaomi_whyred.git` (`lineage-21`)
  - Scope: Device-specific makefiles, overlays, permissions, and device configs.
- **Vendor Tree** (`vendor/xiaomi/whyred`):
  - Remote: `git@github.com:kveld9/proprietary_vendor_xiaomi_whyred.git` (`lineage-21`)
  - Scope: Proprietary blobs, vendor configurations, and module inclusions.
- **Kernel Tree** (`kernel/xiaomi/sdm660`):
  - Remote: `git@github.com:kveld9/android_kernel_xiaomi_sdm660.git` (`lineage-21` and `lineage-21-ksu`)
  - Scope: Linux kernel 4.19 source, defconfigs, drivers, and device tree source (DTS). Parity maintained across both active branches (`lineage-21` stock and `lineage-21-ksu`).
- **Common Device Tree** (`device/xiaomi/sdm660-common`):
  - Remote: `git@github.com:kveld9/android_device_xiaomi_sdm660-common.git` (`lineage-21`)
  - Scope: Shared SDM660 HAL definitions, init scripts, and power configs.
- **Recovery Device Tree** (`../orangefox_device_xiaomi_whyred`):
  - Remote: `git@github.com:kveld9/orangefox_device_xiaomi_whyred.git` (`main`)
  - Scope: OrangeFox / TWRP recovery device tree, FBE configs, and CI compilation workflow.
- **Build System** (`build/make`):
  - Remote: `git@github.com:kveld9/android_build.git` (`lineage-21.0`)
  - Scope: Core build system logic, target packaging rules, and release tools.
- **Build Core Tools** (`build/blueprint`, `build/soong`):
  - Build graph generation, bootstrap configurations, and compilation tools.

---

## 10. Documentation & README Maintenance Policy
- **Synchronize Only Meaningful Changes**: Update `README.md` when repository topology, supported branches, build procedures, patch levels, partition layouts, prerequisites, or release artifacts change.
- **Prevent Documentation Churn**: Do not modify `README.md` for internal bugfixes, code refactorings, or implementation details that do not alter user-facing or documented behavior.
- **Commit Standards**: Documentation updates must be committed with Conventional Commits (e.g., `docs: update README with ...`) in English and pushed to the remote repository.

---

## 11. Prohibition on Hardcoded Local Paths
- **Zero Local Paths in Public Artifacts**: Never include hardcoded local absolute filesystem paths (such as `/home/<username>/...`, user-specific home paths, or local workstation paths) in documentation (`README.md`, guides), scripts, build configurations, or any git-tracked artifacts.
- **Portable & Relative Linking**: All documentation links, cross-references, and script invocations must strictly use relative paths (e.g., `debloat_whyred.sh`, `./scripts/build.sh`) or portable POSIX environment variables (e.g., `${PWD}`, `${HOME}`).

---

## 12. Strict Prohibition on Emoji Usage
- **No Emojis Across Repository & Metadata**: Absolutely no emojis are permitted in technical documentation (`README.md`, `AGENTS.md`), source code, comments, script output logs, commit messages, PR titles, or PR descriptions.
- **Professional Plain-Text Formatting**: Use clear, concise plain-text indicators and standard ASCII tags (e.g., `[INFO]`, `[OK]`, `[WARN]`, `[FAIL]`, `[DRY-RUN]`, standard bullets `*` or `•`) instead of emoji glyphs.

---

## 13. Hardware Validation & Audit Registry Protocol
- **Continuous Audit Documentation**: Every diagnostic gate, physical hardware test, regression audit, or adversarial exploration conducted on the target device must be systematically documented in `AUDIT_REGISTRY.md`.
- **Mandatory Update Cycle**: Whenever hardware tests are executed (whether resulting in `[PASS]`, `[FAIL]`, or `[NOMINAL]`), `AUDIT_REGISTRY.md` must be updated in the same operational unit before proceeding to subsequent tasks or declaring a gate complete.
- **Audit Entry Structure**:
  Each audit entry in `AUDIT_REGISTRY.md` must strictly capture:
  - **Gate / Component**: Target hardware subsystem, driver, or service.
  - **Test Matrix & Scope**: Specific scenarios, operational conditions, and reproduction steps.
  - **Observed Behavior & Evidence**: Raw telemetry, commands, outputs, or panic traces.
  - **Defect Classification & Root Cause**: Detailed causal analysis (or characterization if nominal).
  - **Applied Solution**: Source code modifications, configuration changes, or operational remediations.
  - **Traceability & Commits**: Exact commit hashes, affected repositories, and kernel branch synchronization.
  - **Final Verdict**: Plain-text status indicator (`[PASS]`, `[FAIL]`, `[FIXED]`, `[NOMINAL]`).

---

## 14. Strict English Language Policy
- **Strict English Across All Repository Artifacts**: All documentation, technical notes, hardware diagnostic reports, `AUDIT_REGISTRY.md` entries, source code comments, script outputs, commit messages, and pull request metadata across this repository and all sub-trees must be written strictly and exclusively in English.
- **Independence from Conversation Language**: Regardless of the language used in conversational interactions with the user (e.g., Spanish), no non-English content may ever be committed, recorded, or introduced into `AUDIT_REGISTRY.md`, `README.md`, `AGENTS.md`, or any git-tracked artifact.
