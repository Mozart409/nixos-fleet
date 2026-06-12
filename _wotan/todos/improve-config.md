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

- [ ] **3. CI gives false confidence** — `.github/workflows/ci.yml`. Runs
  `alejandra --check` + `nix flake check`, which *evaluates* but never *realises*
  the system closure. A package that evaluates but fails to compile passes CI.
  `AGENTS.md` even lists `nix build …toplevel` as a validation step CI skips.
  **Fix:** building the full CUDA toplevel on free runners isn't feasible, but add
  at least `nix build .#nixosConfigurations.wotan.config.system.build.toplevel --dry-run`
  to catch missing derivations, or build the home `activationPackage`.

- [ ] **4. `switch.sh` pushes to all remotes *before* building.** The push loop
  runs ahead of `nh os switch`, so a failed build still publishes a broken commit.
  **Fix:** flip the order — build/test first, push only on success.

---

## Medium — consolidation & scaling

- [ ] **5. Scattered duplicate settings** (all merge to the same value, so harmless
  but confusing — give each one owner):
  - `allowUnfree` in **4 places**: `lib/mkConfigs.nix:10`, `flake.nix:99`,
    `modules/nixos/basics.nix:46`, `modules/home-manager/configs/base.nix:12`.
    The last two are redundant (pkgs is already configured via
    `sharedNixpkgsConfig`). Also move `cudaSupport` (only in `basics.nix:46`) into
    `sharedNixpkgsConfig` for a single source of truth.
  - `services.printing.enable` in 3 files: `common-packages.nix:53`,
    `desktop/kde.nix:58`, `desktop/default.nix:171`.
  - `hardware.bluetooth.enable`/`powerOnBoot` in `hosts/wotan/default.nix:89-90`
    duplicate the richer block in `desktop/default.nix` — host lines are dead.
  - `firewall.enable = true` (`common-packages.nix:49`) overlaps the
    `security.hardening` module that owns the firewall (`security.nix:48`).
  - `security.polkit.enable` in `desktop/kde.nix:66` and `desktop/default.nix:240`.

- [ ] **6. "Multi-host" aspiration vs. hardcoded `amadeus`** (33 occurrences;
  `users.users.amadeus` at `common-packages.nix:36`). The flake comments invite
  `laptop`/`server` hosts, but the user is baked into shared modules.
  **Fix:** thread a `username` through `specialArgs`/`mkHost` so shared modules
  are reusable.

- [ ] **7. Top-level NixOS modules imported individually per host** (security,
  razer, moza, vllm in `hosts/wotan/default.nix`). The `desktop/` tree's
  enable-flag pattern is nicer.
  **Fix:** consider a `modules/nixos/default.nix` aggregator that imports all and
  gates each by an `enable` flag — scales as hosts are added.

- [ ] **8. Standalone home-manager** (separate `homeConfigurations`, two-step
  activation). For a single workstation, integrated `home-manager.nixosModules`
  + `home-manager.users.amadeus` avoids drift and a second activation step.
  Preference, not a defect — noting the tradeoff.

---

## Low — polish

- [ ] **9.** `services.pulseaudio.enable = false` with `support32Bit = true` right
  after (`desktop/default.nix`) — the latter is dead config.
- [ ] **10.** `lefthook.yml` runs full `nix flake check` on **pre-commit** (slow,
  every commit) — consider moving to pre-push.
- [ ] **11.** ~~`flatpak-rvgl` does an imperative network install on boot~~
  (removed — no longer using Flatpak).
- [ ] **12.** `README.md` is thin with a typo ("currenlty"); `AGENTS.md` dev-shell
  list omits `cocogitto`/`claude-code`/`agenix`. Minor doc drift.

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
