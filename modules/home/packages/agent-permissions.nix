# wotan's agent rules in Claude's permission syntax: consumed by claude.nix
# directly and translated by opencode.nix, so both agents enforce one list.
{
  allow = [
    # Nix: evaluate, build and search only. Anything that activates a
    # generation is denied below.
    "Bash(nix build *)"
    "Bash(nix eval *)"
    "Bash(nix flake *)"
    "Bash(nix search *)"
    "Bash(nix log *)"
    "Bash(nix path-info *)"
    "Bash(nix why-depends *)"
    "Bash(nh search *)"
    "Bash(nh os build*)"
    "Bash(nh home build*)"
    "Bash(nixos-rebuild build*)"
    "Bash(nixos-rebuild dry-build*)"
    "Bash(just *)"
    "Bash(alejandra *)"
    # git: local, non-destructive subcommands only; everything else asks.
    "Bash(git status*)"
    "Bash(git diff*)"
    "Bash(git log*)"
    "Bash(git show*)"
    "Bash(git blame*)"
    "Bash(git rev-parse*)"
    "Bash(git ls-files*)"
    "Bash(git grep*)"
    "Bash(git branch*)"
    "Bash(git switch*)"
    "Bash(git fetch*)"
    "Bash(git stash*)"
    "Bash(git add *)"
    "Bash(git commit *)"
    # HTTP against the homelab and loopback skips the prompt. This only
    # matches command text; sandbox.network below is the actual boundary.
    "Bash(curl *.homelab.internal*)"
    "Bash(curl *localhost*)"
    "Bash(curl *127.0.0.1*)"
    "Bash(wget *.homelab.internal*)"
    "Bash(wget *localhost*)"
    "Bash(wget *127.0.0.1*)"
    "WebSearch"
    # Homelab gateway (managed-mcp.json); pg*_run_query is read-only.
    "mcp__axon-gateway"
    "mcp__ventara-gateway"
    "Read(~/.config/nixpkgs/config.nix)"
    # agenix recipients file: public keys only.
    "Read(//home/amadeus/code/yggdrasil/infra/secrets/agenix-rules.nix)"
  ];
  # The shared floor (credentials, deploys, GitHub, hook bypass,
  # destructive git) is modules/claude-deny-core.nix, also used by the
  # fleet; below are wotan's own additions.
  deny =
    import ../../claude-deny-core.nix {home = "~";}
    ++ [
      "Read(**/.env*)"
      # agenix ciphertext anywhere, not whole secrets/ dirs: deny beats
      # allow, so a dir-wide deny would also hide the recipients file
      # allowed above.
      "Read(**/.age*)"
      # No root.
      "Bash(sudo *)"
      # Running switch.sh only. A bare *switch.sh* also matched git add,
      # cat and sed on it, so it could not be edited or staged.
      "Bash(infra/hosts/wotan/switch.sh*)"
      "Bash(./infra/hosts/wotan/switch.sh*)"
      "Bash(./switch.sh*)"
      "Bash(bash *switch.sh*)"
      "Bash(sh *switch.sh*)"
      "Bash(*cleanup.sh*)"
      # test-wotan only: a bare `just test*` also caught every project's suite.
      "Bash(just test-wotan*)"
      # Never push: wotan's pushes go through the user's switch.
      "Bash(git push*)"
    ];
}
