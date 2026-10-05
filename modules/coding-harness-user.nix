# Which login the coding-harness modules (coding-harness.nix, herdr.nix,
# claude-permissions.nix, claude-settings-verify.nix, moshi-hook-user.nix)
# render their config into, so none of them hardcodes an account.
#
# Defaults to `amadeus`. The dedicated no-sudo `agent` account that
# development ran its coding agents as from 2026-09-14 was removed on
# 2026-10-05 as unused; the agents run as amadeus again. `hermes` points this
# at its own `hermes` login, the only account on that host.
{
  config,
  lib,
  ...
}: {
  options.homelab.codingHarness = {
    user = lib.mkOption {
      type = lib.types.str;
      default = "amadeus";
      description = "Login the Claude Code / opencode harness modules configure.";
    };
    home = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.homelab.codingHarness.user}";
      defaultText = lib.literalExpression ''"/home/''${config.homelab.codingHarness.user}"'';
      description = "Home directory the harness renders its config into.";
    };
  };
}
