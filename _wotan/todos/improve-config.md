# Improve NixOS Config — Review & TODO

Review of the `/etc/nixos` flake config. Findings are grouped by priority with
file:line references and concrete fixes. Checkboxes track progress.

Baseline at time of review: `nix flake check` passes, CI is green, `alejandra`
clean. The config is well-structured (enable-flag desktop modules, agenix
secrets, documented CVE tradeoffs, CUDA cache wiring). The items below are
improvements, not breakage.

---

## High impact — reproducibility & correctness

- [x] **1. `zinc-oxide` is a local-path flake input** — `flake.nix:50`
  Fixed: changed to `github:Mozart409/zinc_oxide` (kept `flake = false`).
  This also unblocked `nix flake update` — see #2.

- [x] **2. `nix flake update` was silently broken by the local `zinc-oxide` input.**
  Because the input was `git+file://` (unlocked), Nix refused to write `flake.lock`
  at all, so `just update` ran but never persisted changes. The lock file was stuck
  at 2025-11-23 for `nixpkgs`. Fixed by #1 (GitHub URL). After the fix, a normal
  `nix flake update` updated all inputs including `nixpkgs` to 2026-06-10.
  **Automation:** Optional — add a scheduled `update-flake-lock` workflow if desired,
  but manual `just update` now works correctly.

- [x] **3. CI removed entirely.** The GitHub Actions workflow only ran
  `alejandra --check` + `nix flake check` (never built the toplevel), and this
  repo isn't used with CI. Deleted `.github/workflows/ci.yml` and
  `.github/dependabot.yml`. The real safety net is the `lefthook.yml` **pre-push**
  hook: `cog check`, `nh os build`, home `activationPackage --dry-run`, and
  `nix flake check`.

- [x] **4. `switch.sh` pushes to all remotes *before* building.**
  Fixed: `nh os switch` and `nh home switch` now run first. The push loop only
  executes if both succeed. With `set -euo pipefail`, a failed build exits the
  script before any push happens.

---

## Medium — consolidation & scaling

- [x] **5. Scattered duplicate settings** — deduplicated and given single owners:
  - `allowUnfree` + `cudaSupport`: moved both into `sharedNixpkgsConfig` in
    `lib/mkConfigs.nix` (single source of truth). Removed from `basics.nix`,
    `base.nix`, and `flake.nix` devShell (now uses `sharedNixpkgsConfig`).
  - `services.printing.enable`: removed from `common-packages.nix` and `kde.nix`;
    kept in `desktop/default.nix`.
  - `hardware.bluetooth.enable`/`powerOnBoot`: removed from `hosts/wotan/default.nix`;
    kept in `desktop/default.nix`.
  - `firewall.enable = true`: removed from `common-packages.nix`; owned by
    `security.nix` (enabled when `security.hardening.enable = true`).
  - `security.polkit.enable`: removed from `desktop/kde.nix`; kept in
    `desktop/default.nix`.
  - `services.gvfs.enable` / `services.udisks2.enable`: removed from `kde.nix`;
    kept in `desktop/default.nix`.

- [x] **6. `username` threaded through `mkHost`.** `mkHost` now takes a third
  arg (`mkHost "wotan" system "amadeus"`) and passes `username` via
  `specialArgs` (system) and `extraSpecialArgs` (home). Shared modules
  (`basics`, `common-packages`, `razer`, `desktop/hyprland`,
  `desktop/next-wallpaper`, home `base`) take `{username, ...}` instead of
  hardcoding `amadeus`; host-specific spots (autoLogin, tmpfiles, age owners,
  ssh `Match User`) interpolate it too. Remaining literals are identity
  (git email/name, ssh key material in `secrets.nix`), which are not
  username-derived.

- [x] **7. `modules/nixos/default.nix` aggregator added.** Hosts now import the
  single directory `../../modules/nixos` instead of listing each module. Every
  optional module is gated by its own `enable` flag; added flags to the two that
  lacked them — `hardware.moza.enable` (`moza.nix`) and
  `programs.claudeCodeMcp.enable` (`claude-code.nix`) — both enabled on wotan to
  preserve prior always-on behavior.

- [x] **8. Standalone home-manager** — integrated into NixOS.
  Removed `homeConfigurations` from `flake.nix` and `mkHome` from `lib/mkConfigs.nix`.
  Added `home-manager.nixosModules.home-manager` to `mkHost` so a single
  `nixos-rebuild switch` activates both system and user config. Updated
  `switch.sh`, `justfile`, `lefthook.yml`, and `AGENTS.md` to remove the
  standalone `home-manager switch` / `nh home switch` steps.

---

## Low — polish

- [x] **9.** `services.pulseaudio.support32Bit = true` — removed from
  `desktop/default.nix` (pulseaudio is disabled, so the option is dead).
- [x] **10.** `lefthook.yml` runs full `nix flake check` on **pre-commit** (slow,
  every commit) — moved to pre-push. `nix flake check` stays in pre-commit, but
  `nh os build` and `nh home build` moved to pre-push.
- [ ] **11.** ~~`flatpak-rvgl` does an imperative network install on boot~~
  (removed — no longer using Flatpak).
- [x] **12.** Fixed `README.md` typo ("currenlty" → "currently"); `AGENTS.md`
  dev-shell list now includes `cocogitto`/`claude-code`/`agenix`, and the
  "Adding New Hosts" section documents the new `mkHost … "username"` signature
  and the `modules/nixos` aggregator.

## Not a bug (do not "fix")

- `system.stateVersion = "24.11"` (`hosts/wotan/default.nix:243`) and
  `home.stateVersion = "24.11"` (`home-manager/configs/base.nix:28`) are correct —
  stateVersion pins to the install version and must not track current nixpkgs.
- Multiple `nixpkgs` copies in `flake.lock` (nixpkgs_2..5) come from the Hyprland
  ecosystem deliberately not following nixpkgs (for their cachix) — intentional.
- vLLM 0.16.0 CVEs are documented with mitigations (loopback bind, trusted repos)
  in `modules/nixos/vllm.nix` — track the nixpkgs bump, no action needed now.

---

## Suggested first batch (low-risk, high-value)

1. #1 zinc-oxide → GitHub URL
2. #4 switch.sh build-before-push
3. #5 dedup settings
4. #2 add update-flake-lock workflow

Verify each with `nix flake check` + `alejandra .` before committing (separate
commits per item).
