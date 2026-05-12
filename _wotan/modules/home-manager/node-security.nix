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

  home.file = {
    # npm + pnpm configuration (pnpm reads .npmrc)
    ".npmrc".text = ''
      ## === SUPPLY CHAIN SECURITY === ##

      # npm: 7-day minimum release age (days)
      min-release-age=7

      # pnpm: 7-day minimum release age (10080 minutes)
      minimum-release-age=10080

      # pnpm: Strictly enforce minimum-release-age (fail instead of warn)
      minimum-release-age-strict=true

      # pnpm: Block git/tarball dependencies in transitive deps (default in pnpm 11)
      block-exotic-subdeps=true

      # pnpm: Verify integrity of packages in store
      verify-store-integrity=true

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

      # pnpm: strict peer dependencies
      strict-peer-dependencies=true

      # pnpm: don't hoist by default (prevents phantom dependencies)
      shamefully-hoist=false

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

  # Shell aliases - bun requires explicit --config flag for global config
  # See: https://github.com/oven-sh/bun/issues/26408
  programs.zsh.shellAliases = {
    # Wrap bun commands to use global security config
    bun = "command bun --config ~/.bunfig.toml";
    bunx = "command bunx --config ~/.bunfig.toml";
  };

  programs.bash.shellAliases = {
    bun = "command bun --config ~/.bunfig.toml";
    bunx = "command bunx --config ~/.bunfig.toml";
  };
}
