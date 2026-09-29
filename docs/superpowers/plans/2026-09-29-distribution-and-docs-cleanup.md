# Distribution and Documentation Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make local installs and Homebrew updates safe, version-identifiable, and accurately documented for open-source users.

**Architecture:** Every bundle replacement follows the same guarded process check; `--open` controls relaunch only. Documentation distinguishes released v0.3.0 behavior from current-branch Calendar functionality. Build metadata derives from one version source used by each packaging path.

**Tech Stack:** POSIX shell, Ruby Homebrew formula, plist metadata, Markdown.

**Spec:** `docs/superpowers/specs/2026-09-29-full-repository-cleanup-design.md`

## Global Constraints

- Never broad-kill processes; inspect only the exact destination bundle process.
- Preserve source-build, Homebrew, resource-copy, and ad-hoc-signing behavior.
- Do not publish a release or alter a remote Homebrew tap.
- Test first; run lifecycle tests, package tests, and `git diff --check` before commit.

## Review Focus

- A normal update cannot replace a running destination bundle without a controlled stop.
- A Homebrew upgrade cannot be described as updating the copied Applications bundle unless it actually does.
- Released documentation never presents current-branch Calendar work as stable v0.3.0 functionality.
- Every delivered bundle exposes a coherent version/build value.

---

### Task 1: Safe installs, version metadata, and truthful docs

**Files:**
- Modify: `install.sh`, `Formula/timezoner.rb`, `scripts/test-install-lifecycle.sh`, `scripts/build.sh`, `scripts/create-dmg.sh`, `scripts/test-install.sh`, `app/Info.plist`, `README.md`, `docs/RELEASE_READINESS.md`

**Interfaces:**
- Produces the same guarded replacement protocol for default and `--open` installs.
- Produces documented explicit Homebrew app-sync behavior and one version value for all bundle builders.

- [ ] Write failing shell/Ruby fixture tests for default replacement with a running exact destination, Homebrew copy sync/conflict behavior, and bundle version metadata.
- [ ] Run lifecycle/package tests and confirm default replacement lacks the guard or version metadata is absent.
- [ ] Guard every replacement, use `--open` only for relaunch, choose and document a single explicit Homebrew copied-app update command, derive/validate version metadata consistently, and correct stale README/release text/examples/assertions.
- [ ] Run `bash scripts/test-install-lifecycle.sh all`, `bash scripts/test-install.sh`, `./scripts/build.sh`, `plutil -lint app/Info.plist`, and `git diff --check`.
- [ ] Commit only distribution/docs changes.
