# Deny rules every Claude Code install in this repo carries, whatever writes
# its settings: wotan's home-manager module (modules/home/packages/claude.nix)
# and the fleet's claude-permissions-data.nix (development, hermes) both append
# this list to their own. Each side keeps its own allow list, its own extra
# denies and its own mechanism; this is only the shared floor.
#
# Only ever add here. A rule that one side must not have belongs in that side's
# own list, and removing a rule from this file loosens every host at once.
#
# `home` is the home-directory prefix in Claude's rule syntax: "~" on wotan,
# "/${home}" (an absolute `//home/...` path) on the fleet.
{home}: [
  # Credentials, and agenix ciphertext anywhere (the recipients file stays
  # readable through each side's allow rules).
  "Read(${home}/.ssh/**)"
  "Read(${home}/.gnupg/**)"
  "Read(${home}/.claude/.credentials.json)"
  "Read(${home}/.local/share/opencode/auth.json)"
  "Read(${home}/.config/sops/age/**)"
  "Read(${home}/.config/age/**)"
  "Read(//etc/ssh/ssh_host_*)"
  # /run/agenix is a symlink to /run/agenix.d/<gen>; deny the real directory.
  "Read(//run/agenix.d/**)"
  "Read(**/*.age)"

  # Activating a generation or deploying. Agents write configuration; applying
  # it is the user's decision. Builds (`nh os build`, `just colmena-build`)
  # stay allowed.
  "Bash(*nixos-rebuild*switch*)"
  "Bash(*nixos-rebuild*boot*)"
  "Bash(*nixos-rebuild*test*)"
  "Bash(*os switch*)"
  "Bash(*os boot*)"
  "Bash(*os test*)"
  "Bash(*home switch*)"
  "Bash(*home-manager*switch*)"
  "Bash(*switch-to-configuration*)"
  "Bash(nixos-install*)"
  "Bash(colmena apply*)"
  # The same deploys through the task runner: `Bash(just *)` allows are matched
  # against the command line, not the recipe body, so each wrapper needs a rule.
  "Bash(just ca*)"
  "Bash(just colmena-apply*)"
  "Bash(just colmena-reboot*)"
  "Bash(just deploy*)"
  "Bash(just switch*)"

  # Publishing to GitHub (wotan only, by the user) and the GitHub CLI. Forgejo
  # is the forge; GitHub is a mirror nobody but the user writes to.
  "Bash(just export-github*)"
  "Bash(*export-github.sh*)"
  "Bash(just sync-remotes*)"
  "Bash(gh)"
  "Bash(gh *)"

  # History that exists nowhere else, and the hooks and signing that guard it.
  "Bash(git push --force*)"
  "Bash(git push -f*)"
  "Bash(git *--no-verify*)"
  "Bash(git commit -n*)"
  "Bash(git commit * -n*)"
  "Bash(git *--no-gpg-sign*)"
  "Bash(git *commit.gpgsign*)"
  "Bash(git *core.hooksPath*)"
  "Bash(*LEFTHOOK*)"
  "Bash(*GIT_CONFIG_*)"

  # Destructive working-tree operations.
  "Bash(git reset *--hard*)"
  "Bash(git clean*)"
  "Bash(git checkout -- *)"
  "Bash(git checkout .*)"
  "Bash(git restore .*)"

  # The Nix store, the profile and the machine itself.
  "Bash(nix profile *)"
  "Bash(nix-env *)"
  "Bash(nh clean*)"
  "Bash(nix-collect-garbage*)"
  "Bash(nix store delete*)"
  "Bash(nix-store --delete*)"
  "Bash(sudo rm *)"
  "Bash(rm -rf /*)"
  "Bash(rm -rf ~*)"
  "Bash(mkfs*)"
  "Bash(dd if=* of=/dev/*)"
  "Bash(shutdown*)"
  "Bash(reboot*)"
  "Bash(poweroff*)"
  "Bash(halt*)"
  "Bash(systemctl reboot*)"
  "Bash(systemctl poweroff*)"
]
