{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.sopsEnv;

  # One-shot migration: .env -> .sops.env. The dotenv is first normalized to
  # the strict KEY=value form sops stores literally (see the .py), encrypted,
  # verified by decrypting again, then the plaintext is removed and .env kept
  # out of git.
  env2sops = pkgs.writeShellApplication {
    name = "env2sops";
    runtimeInputs = with pkgs; [sops coreutils diffutils git python3];
    text = ''
      src="''${1:-.env}"
      dst="$(dirname "$src")/.sops.env"

      [ -f "$src" ] || { echo "env2sops: $src not found" >&2; exit 1; }
      [ -e "$dst" ] && { echo "env2sops: $dst already exists, refusing to overwrite" >&2; exit 1; }

      # Normalized plaintext lives only in a private tmp file for the
      # duration of this script.
      norm="$(mktemp)"
      trap 'shred -u "$norm" 2>/dev/null || rm -f "$norm"' EXIT
      python3 ${./env2sops-normalize.py} "$src" "$norm"

      # Recipients come from the nearest .sops.yaml (see sopsEnv.rulesDir).
      cp "$norm" "$dst"
      sops --encrypt --in-place "$dst"

      # sops drops blank lines on rewrite, so compare modulo those.
      if ! diff -q <(grep -v '^[[:space:]]*$' "$norm") <(sops --decrypt "$dst" | grep -v '^[[:space:]]*$') >/dev/null; then
        echo "env2sops: round-trip mismatch, keeping $src and removing $dst" >&2
        rm -f "$dst"
        exit 1
      fi

      # Best effort: on CoW/SSD storage shred is not a guarantee, but the
      # plaintext already lived here and this is still better than rm.
      shred -u "$src"

      if top="$(git -C "$(dirname "$dst")" rev-parse --show-toplevel 2>/dev/null)"; then
        gi="$top/.gitignore"
        if ! grep -qxE '/?\.env|\*\.env' "$gi" 2>/dev/null; then
          echo ".env" >>"$gi"
          echo "env2sops: added .env to $gi"
        fi
      fi

      echo "env2sops: $src -> $dst (safe to commit)"
      echo "  edit:   sops $dst"
      echo "  use:    sops exec-env $dst 'your command'"
    '';
  };
in {
  options.sopsEnv = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Per-project encrypted dotenv files with sops. Secrets live in
        `.sops.env` (dotenv store: keys visible, values encrypted, safe to
        commit) and are injected into a single child process with
        `sops exec-env` -- never written to disk or exported into the shell.
        Replaces `set dotenv-load` in justfiles.
      '';
    };

    pgpFingerprint = lib.mkOption {
      type = lib.types.str;
      description = ''
        Full fingerprint (40 hex chars) of the GPG key used as the interactive
        recipient. Decryption goes through gpg-agent, so the private key is
        passphrase-encrypted at rest and pinentry gates a cold cache. The key
        needs an encryption-capable subkey:
        `gpg --quick-add-key <fingerprint> cv25519 encr 2y`.
      '';
    };

    ageRecipients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Extra age public keys (age1...) added as recipients for
        non-interactive consumers such as servers or CI.
      '';
    };

    rulesDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/code";
      description = ''
        Directory that receives the shared `.sops.yaml`. sops walks up from
        the working directory to find creation rules, so one file here covers
        every project below it; a project's own `.sops.yaml` still wins.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [pkgs.sops env2sops];

    # The encryption subkey cannot be created declaratively (new private key
    # material, signed with the passphrase-protected primary key), so warn on
    # every switch until it exists. Reads the public keyring only -- no agent,
    # no pinentry. Colon format: field 2 = validity, field 12 = capabilities.
    home.activation.sopsEnvCheckGpgSubkey = lib.hm.dag.entryAfter ["writeBoundary"] ''
      _gpg="${pkgs.gnupg}/bin/gpg"
      _fpr="${cfg.pgpFingerprint}"
      if ! _keys="$("$_gpg" --batch --quiet --list-keys --with-colons "$_fpr" 2>/dev/null)"; then
        warnEcho "sopsEnv: GPG key $_fpr not found in the keyring; sops cannot encrypt .sops.env files"
      elif ! printf '%s\n' "$_keys" | ${pkgs.gawk}/bin/awk -F: '$1 == "sub" && $2 !~ /[rei]/ && $12 ~ /e/ { found = 1 } END { exit !found }'; then
        warnEcho "sopsEnv: GPG key $_fpr has no usable encryption subkey; run: gpg --quick-add-key $_fpr cv25519 encr 2y"
      fi
    '';

    home.file."${cfg.rulesDir}/.sops.yaml".text = ''
      # Managed by home-manager (modules/home/packages/sops.nix).
      # Applies to every project below this directory unless it has its own.
      creation_rules:
        - path_regex: \.sops\.env$
          pgp: ${cfg.pgpFingerprint}
          ${lib.optionalString (cfg.ageRecipients != []) "age: ${lib.concatStringsSep "," cfg.ageRecipients}"}
    '';
  };
}
