{
  config,
  pkgs,
  lib,
  ...
}: {
  # Global npm/pnpm/bun configuration with supply-chain security hardening
  #
  # All three enforce:
  # - 7-day minimum release age (blocks newly published packages)
  # - Lifecycle scripts disabled by default
  # - Lockfile enforcement
  #
  # References:
  # - https://pnpm.io/supply-chain-security
  # - https://bun.com/docs/pm/npmrc
  # - https://docs.npmjs.com/cli/v11/using-npm/config

  # pnpm >= 11 reads only registry/auth settings from .npmrc; everything else
  # comes from this global config (camelCase keys). Check a key with
  # `pnpm config get <key>` outside any project. blockExoticSubdeps (on by
  # default since pnpm 11), strictPeerDependencies and shamefullyHoist (off by
  # default) are not accepted globally, only in a project's
  # pnpm-workspace.yaml, so they are left out here.
  xdg.configFile."pnpm/config.yaml".text = ''
    # 7-day minimum release age (minutes), failing instead of warning
    minimumReleaseAge: 10080
    minimumReleaseAgeStrict: true

    # Verify integrity of packages in the store
    verifyStoreIntegrity: true

    # Disable lifecycle scripts by default (review manually)
    ignoreScripts: true

    # Enforce exact versions (no ^ or ~)
    saveExact: true
  '';

  home.file = {
    # npm configuration. pnpm-only keys live in pnpm/config.yaml above; npm
    # warns about every key it does not know.
    ".npmrc".text = ''
      ## === SUPPLY CHAIN SECURITY === ##

      # npm: 7-day minimum release age (days)
      min-release-age=7

      ## === SCRIPT EXECUTION === ##

      # Disable postinstall scripts by default (review manually)
      ignore-scripts=true

      ## === LOCKFILE & VERSIONING === ##

      # Require package-lock/pnpm-lock
      package-lock=true

      # Enforce exact versions (no ^ or ~)
      save-exact=true

      ## === AUDIT === ##

      # Run audit on install
      audit=true

      # Only fail audit on high/critical (not low/moderate)
      audit-level=high

      ## === MISC === ##

      # Disable funding messages (cleaner output)
      fund=false

      # Global install location (survives dev shell entry)
      prefix=''${HOME}/.npm-global
    '';

    # bun configuration
    ".bunfig.toml".text = ''
      [install]
      # Global install location
      globalDir = "~/.bun/install/global"
      globalBinDir = "~/.bun/bin"

      # Security: 7-day minimum release age (604800 seconds)
      minimumReleaseAge = 604800

      # Security: disable lifecycle scripts by default
      # Bun maintains an internal allowlist for known-safe packages
      # Add per-project exceptions to package.json "trustedDependencies"
      auto = "disable"

      # Prefer offline cache when available
      prefer-offline = true
    '';
  };

  # Environment variables for consistent paths
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
    PNPM_HOME = "$HOME/.local/share/pnpm";
    BUN_INSTALL = "$HOME/.bun";

    # Disable npm update notifier (reduces network calls)
    NO_UPDATE_NOTIFIER = "1";
  };

  # Add tool paths
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.local/share/pnpm"
    "$HOME/.bun/bin"
  ];
}
