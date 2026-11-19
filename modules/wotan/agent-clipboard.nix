{
  config,
  lib,
  pkgs,
  ...
}: let
  # Bridges the owner's Wayland clipboard to the agent so Claude Code can paste
  # images. The agent has no /run/user and no WAYLAND_DISPLAY, so a socket
  # activated user service of the owner answers instead. The agent sees only
  # image types and never text (a copied password stays out of reach); the
  # 0710 directory around the socket is the gate.
  cfg = config.wotan.agentUser;

  wlPaste = "${pkgs.wl-clipboard}/bin/wl-paste";
  grep = "${pkgs.gnugrep}/bin/grep";
  cat = "${pkgs.coreutils}/bin/cat";

  # Runs as the owner, once per connection, with the socket as stdin/stdout.
  # The request is untrusted: one short line, matched against a fixed shape,
  # and only image types are ever listed or read. The user manager's PATH is
  # sparse, hence the store paths.
  server = pkgs.writeShellScript "agent-clipboard-server" ''
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      for s in "$XDG_RUNTIME_DIR"/wayland-*; do
        case $s in *.lock) continue ;; esac
        [ -S "$s" ] || continue
        export WAYLAND_DISPLAY=$s
        break
      done
    fi
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo err
      exit 0
    fi

    IFS= read -r -t 5 -n 64 req || true
    types=$(${wlPaste} --list-types 2>/dev/null | ${grep} '^image/')

    re='^image/[a-z0-9.+-]{1,40}$'
    if [ "$req" = list ]; then
      if [ -n "$types" ]; then
        echo ok
        echo "$types"
      else
        echo err
      fi
    elif [[ $req =~ $re ]] && printf '%s\n' "$types" | ${grep} -qxF -- "$req"; then
      echo ok
      exec ${wlPaste} --no-newline --type "$req"
    else
      echo err
    fi
  '';

  # What the agent's PATH finds first: Claude Code's `wl-paste -l` and
  # `wl-paste --type image/png` go through the socket, a plain text paste
  # is refused.
  shim = pkgs.writeShellScriptBin "wl-paste" ''
    set -o pipefail
    req=
    while [ $# -gt 0 ]; do
      case $1 in
        -l | --list-types) req=list ;;
        -t | --type)
          shift
          req=''${1:-}
          ;;
        --type=*) req=''${1#--type=} ;;
        -n | --no-newline) ;;
        *)
          req=
          break
          ;;
      esac
      shift
    done
    if [ -z "$req" ]; then
      echo "wl-paste (agent): only clipboard images are shared with the agent" >&2
      exit 1
    fi

    # -t 30: after the request's EOF socat would otherwise give the reply
    # only 0.5 s, which truncates a large image.
    printf '%s\n' "$req" \
      | ${pkgs.socat}/bin/socat -t 30 - UNIX-CONNECT:/run/agent-clipboard/sock \
      | {
        IFS= read -r hdr
        [ "$hdr" = ok ] || exit 1
        ${cat}
      }
  '';
in {
  config = lib.mkIf cfg.enable {
    # The 0710 directory is the access gate: only the owner and the agent
    # group can reach the socket inside it, whatever its own mode says.
    systemd.tmpfiles.rules = [
      "d /run/agent-clipboard 0710 ${cfg.owner} ${cfg.user} -"
    ];

    # Socket-activated in the owner's session manager, because only that
    # session can see the Wayland clipboard (the agent's namespace has no
    # /run/user). One short-lived instance per connection.
    systemd.user.sockets.agent-clipboard = {
      unitConfig.ConditionUser = cfg.owner;
      wantedBy = ["sockets.target"];
      listenStreams = ["/run/agent-clipboard/sock"];
      socketConfig = {
        Accept = true;
        # World-writable on purpose: the 0710 parent dir does the gating.
        SocketMode = "0666";
      };
    };

    systemd.user.services."agent-clipboard@" = {
      unitConfig.ConditionUser = cfg.owner;
      serviceConfig = {
        ExecStart = server;
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "journal";
        RuntimeMaxSec = 30;
      };
    };

    # Lands in /etc/profiles/per-user/<agent>/bin, ahead of the real
    # wl-paste in /run/current-system/sw/bin.
    users.users.${cfg.user}.packages = [shim];
  };
}
