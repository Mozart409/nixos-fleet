{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.desktop.quickshell;
  quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Audio switch script using rofi
  audio-switch = pkgs.writeShellScriptBin "audio-switch" ''
    set -euo pipefail

    # List all audio sinks
    sinks=$(${pkgs.wireplumber}/bin/wpctl status | sed -n '/Audio/,/Video/{/Sinks:/,/Sources:/p}' | grep -E '^\s*[│├└].*[0-9]+\.' | sed 's/[│├└]//g; s/^\s*//')

    if [ -z "$sinks" ]; then
      ${pkgs.libnotify}/bin/notify-send "Audio" "No audio sinks found"
      exit 1
    fi

    # Show rofi menu
    selected=$(echo "$sinks" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "󰓃 Audio Output" -theme-str 'window {width: 450px;}')

    if [ -n "$selected" ]; then
      sink_id=$(echo "$selected" | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
      if [ -n "$sink_id" ]; then
        ${pkgs.wireplumber}/bin/wpctl set-default "$sink_id"
        sink_name=$(echo "$selected" | sed 's/^[* ]*[0-9]*\. //' | cut -d'[' -f1 | xargs)
        ${pkgs.libnotify}/bin/notify-send "󰓃 Audio" "Switched to: $sink_name"
      fi
    fi
  '';

  # Backs DepsWidget.qml: reports which direct flake inputs have actually moved
  # upstream. Kept as a real script rather than an inline `sh -c` because it
  # parses flake.lock and fans out a dozen `git ls-remote` calls in a thread
  # pool -- 2s instead of 7s, and not something to write twice-escaped inside
  # QML.
  flake-drift = pkgs.writeShellScriptBin "flake-drift" ''
    exec ${pkgs.python3}/bin/python3 ${./quickshell-flake-drift.py} \
      --grace-days ${toString cfg.flakeDriftGraceDays} "$@"
  '';

  # Backs HomeAssistantWidget.qml, and the only thing in the shell that talks to
  # HA. The token is read from the agenix file on every call and fed to curl as
  # a header file through process substitution, so it never lands in an argv
  # (visible in /proc to every process), the service environment, or QML.
  # `set` only accepts the entity ids declared below, so the panel cannot
  # be used to call anything else on HA.
  #
  #   quickshell-ha states       -> {"entities":[{id,name,state}]} | {"error":".."}
  #   quickshell-ha set <id> on|off  -> <domain>.turn_on / turn_off
  #
  # Explicit on/off rather than `toggle`: the panel sends what the user saw
  # flip, so a click against a not-yet-refreshed state can never invert the
  # wrong way.
  haEntities = builtins.toJSON cfg.homeAssistant.entities;
  quickshell-ha = pkgs.writeShellScriptBin "quickshell-ha" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [pkgs.curl pkgs.jq pkgs.coreutils]}

    url=${lib.escapeShellArg (lib.removeSuffix "/" cfg.homeAssistant.url)}
    tokenFile=${lib.escapeShellArg cfg.homeAssistant.tokenFile}
    entities=${lib.escapeShellArg haEntities}

    fail() {
      jq -cn --arg e "$1" '{error: $e}'
      exit 1
    }

    [[ -r $tokenFile ]] || fail "token unreadable: $tokenFile"

    header() {
      printf 'Authorization: Bearer %s\n' "$(tr -d '[:space:]' <"$tokenFile")"
    }

    api() {
      curl -sf --max-time 5 -H @<(header) -H 'Content-Type: application/json' "$@"
    }

    case "''${1:-}" in
      states)
        bodies=()
        while read -r id; do
          if body=$(api "$url/api/states/$id"); then
            bodies+=("$body")
          fi
        done < <(jq -r '.[].id' <<<"$entities")
        # Every request failing is HA (or the tailnet) being down, or the token
        # being rejected -- worth telling apart, since only one of them is
        # fixed on this machine. A single missing entity is just left off.
        if (( ''${#bodies[@]} == 0 )); then
          code=$(curl -s -o /dev/null --max-time 5 -w '%{http_code}' -H @<(header) "$url/api/" || true)
          [[ $code == 401 ]] && fail "token rejected (401)"
          fail "home assistant unreachable"
        fi
        printf '%s\n' "''${bodies[@]}" | jq -sc --argjson ents "$entities" '
          (map({key: .entity_id, value: .}) | from_entries) as $s
          | {entities: [$ents[] | select($s[.id]) | {
              id,
              name: (.label // $s[.id].attributes.friendly_name // .id),
              state: $s[.id].state
            }]}'
        ;;
      set)
        id=''${2:?usage: quickshell-ha set <entity_id> on|off}
        target=''${3:-}
        [[ $target == on || $target == off ]] || fail "target must be on or off"
        jq -e --arg id "$id" 'any(.[]; .id == $id)' <<<"$entities" >/dev/null \
          || fail "not an allowed entity: $id"
        api -X POST -d "$(jq -cn --arg id "$id" '{entity_id: $id}')" \
          "$url/api/services/''${id%%.*}/turn_$target" >/dev/null \
          || fail "turn_$target failed: $id"
        ;;
      *)
        echo "usage: quickshell-ha states | set <entity_id> on|off" >&2
        exit 2
        ;;
    esac
  '';

  # Runtime dependencies for shell scripts and widgets. The resource widgets
  # shell out on a timer, so everything they call has to be on the service's
  # PATH -- a missing binary shows up as a permanently blank readout, not an
  # error.
  dependencies = with pkgs; [
    bash
    coreutils # cat, df -- disk and hwmon readouts
    gawk # /proc/stat and free parsing
    gnugrep
    procps # free
    curl # weather widget, and the homelab board's prometheus reads
    git # flake-drift's ls-remote sweep
    wireplumber # for wpctl audio control
    libnotify # for notify-send
    rofi # for audio device selection menu
  ];

  # The bar has to show the same workspaces on a monitor that Hyprland actually
  # binds to it, so both are rendered from the single declaration in
  # desktop.hyprland-configs.workspaces. Keying off Hyprland's numeric monitor
  # id instead would be wrong: those ids are handed out in the order outputs get
  # enabled, so they swap between sessions (and on re-plug/DPMS) while the
  # workspace rules stay pinned to the output *name*.
  hyprWorkspaces =
    lib.filter (w: w.showInBar)
    config.desktop.hyprland-configs.workspaces;
  sortedIds = ws: lib.sort (a: b: a < b) (lib.unique (map (w: w.id) ws));
  idList = ws: lib.concatMapStringsSep ", " toString (sortedIds ws);

  monitorEntries =
    lib.concatStringsSep ",\n    "
    (lib.mapAttrsToList (output: ws: ''"${output}": [${idList ws}]'')
      (lib.groupBy (w: w.monitor) hyprWorkspaces));

  # Monitor owning the lowest workspace number -- the one widgets that should
  # only appear once (git status) attach to.
  primaryOutput =
    if hyprWorkspaces == []
    then ""
    else (lib.head (lib.sort (a: b: a.id < b.id) hyprWorkspaces)).monitor;

  workspaceLayoutQml = ''
    pragma Singleton

    // Generated by modules/home/packages/quickshell.nix -- do not edit.
    import QtQuick

    QtObject {
      // Output name, as reported by `hyprctl monitors`, -> workspaces shown there.
      readonly property var byMonitor: ({
        ${monitorEntries}
      })

      // Used for outputs with no rule of their own (hotplugged screens).
      readonly property var fallback: [${idList hyprWorkspaces}]

      readonly property string primary: "${primaryOutput}"
    }
  '';

  # Nix-level decisions the QML needs to see. Same trick as WorkspaceLayout:
  # a generated singleton on the import path, so the hand-written config
  # directory stays free of generated files and can be symlinked for liveReload.
  featuresQml = ''
    pragma Singleton

    // Generated by modules/home/packages/quickshell.nix -- do not edit.
    import QtQuick

    QtObject {
      // True when desktop.notifications.backend = "quickshell". The daemon must
      // not be instantiated otherwise: org.freedesktop.Notifications has a
      // single owner and dunst is already holding it.
      readonly property bool notifications: ${lib.boolToString (config.desktop.notifications.backend == "quickshell")}

      // desktop.quickshell.homeAssistant.enable -- without it the
      // quickshell-ha script is not installed and the panel would only ever
      // show an error.
      readonly property bool homeAssistant: ${lib.boolToString cfg.homeAssistant.enable}
    }
  '';

  # The generated layout ships as its own QML module on the import path rather
  # than as a file inside the config directory. That keeps the config directory
  # 100% hand-written, which is what lets `liveReload` point it straight at the
  # source tree -- a directory that mixes tracked sources with a Nix-generated
  # file cannot be symlinked anywhere useful.
  generatedQml = pkgs.runCommand "quickshell-generated-qml" {} ''
    mkdir -p $out/Generated
    cat > $out/Generated/qmldir <<'EOF'
    module Generated
    singleton WorkspaceLayout 1.0 WorkspaceLayout.qml
    singleton Features 1.0 Features.qml
    EOF
    cp ${pkgs.writeText "WorkspaceLayout.qml" workspaceLayoutQml} $out/Generated/WorkspaceLayout.qml
    cp ${pkgs.writeText "Features.qml" featuresQml} $out/Generated/Features.qml
  '';

  # QML import paths for Qt6
  qmlImportPath = lib.concatStringsSep ":" [
    "${quickshell}/lib/qt-6/qml"
    "${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml"
    "${generatedQml}"
  ];

  quickshellConfig = pkgs.runCommand "quickshell-config" {} ''
    mkdir -p $out
    cp ${./quickshell}/*.qml $out/
  '';
in {
  imports = [
    ../services/hyprland-session.nix
    ./hyprland-configs.nix
    ./notifications.nix
  ];

  options.desktop.quickshell = {
    enable = lib.mkEnableOption "quickshell custom widgets";

    liveReload = lib.mkEnableOption ''
      pointing ~/.config/quickshell straight at the source tree instead of a
      read-only copy in the Nix store.

      Quickshell watches its config directory and reloads on any change, so
      with this on, editing a .qml file under sourcePath updates the bar
      immediately -- including brand-new widget files -- with no rebuild. The
      cost is that the running shell no longer matches what the flake builds
      until you rebuild, so leave it off unless you are actively working on
      the widgets
    '';

    flakeDriftGraceDays = lib.mkOption {
      type = lib.types.number;
      default = 3;
      description = ''
        How stale a drifted input's lock must be before DepsWidget counts it
        as something to act on.

        Drift alone ("locked rev != upstream HEAD") becomes true of any input
        tracking a fast-moving branch within hours of every update -- nixpkgs
        follows nixos-unstable, which lands a channel commit several times a
        day -- so an ungated drift count sits permanently amber no matter how
        often you update, which is a board you learn to ignore. Gating on lock
        age keeps the honest half of the signal (nothing drifted is ever shown
        as current; it stays listed, just demoted) while letting a machine
        that updates regularly actually read "all current".

        Raise it if you update less often than every few days.
      '';
    };

    homeAssistant = {
      enable = lib.mkEnableOption "the Home Assistant quick-toggle desktop panel";

      url = lib.mkOption {
        type = lib.types.str;
        example = "https://homeassistant.example.ts.net";
        description = "Base URL of the Home Assistant instance.";
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        example = "/run/agenix/ha-token";
        description = ''
          Runtime path (not a store path) to a file holding a raw HA long-lived
          access token, no KEY= prefix. Read on every request, so rotating the
          token needs no restart.
        '';
      };

      entities = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              example = "switch.kitchen_light";
              description = "Entity id; its domain must support `turn_on`/`turn_off`.";
            };
            label = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Display name; null uses HA's friendly_name.";
            };
          };
        });
        default = [];
        description = "Entities shown, in order. Also the allowlist for toggling.";
      };
    };

    sourcePath = lib.mkOption {
      type = lib.types.str;
      default = "/home/amadeus/code/yggdrasil/infra/modules/home/packages/quickshell";
      description = ''
        Absolute path to the QML sources, used only when liveReload is on.
        Must be a real path on the running system, not a store path.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      [
        quickshell
        audio-switch # Rofi-based audio output switcher
        flake-drift # Backs the flake-input drift widget
      ]
      ++ lib.optionals cfg.homeAssistant.enable [
        quickshell-ha # Backs the Home Assistant toggle panel
      ]
      ++ [
        pkgs.pwvucontrol # Modern PipeWire volume control GUI (bar: right-click volume)
        pkgs.pulsemixer # TUI audio mixer
      ];

    # Set QML import path for proper module resolution
    home.sessionVariables.QML2_IMPORT_PATH = qmlImportPath;

    # Either a read-only copy of the QML in the store (the default), or a
    # symlink to the working tree for live editing. The generated
    # WorkspaceLayout singleton reaches both through QML2_IMPORT_PATH.
    xdg.configFile."quickshell".source =
      if cfg.liveReload
      then config.lib.file.mkOutOfStoreSymlink cfg.sourcePath
      else quickshellConfig;

    # Systemd service for Quickshell
    systemd.user.services.quickshell = {
      Unit = {
        Description = "Quickshell custom widgets";
        PartOf = ["hyprland-session.target"];
        After = ["hyprland-session.target"];
      };

      Service = {
        Environment = [
          "PATH=/run/wrappers/bin:${lib.makeBinPath dependencies}:/run/current-system/sw/bin:${config.home.profileDirectory}/bin"
          "QML2_IMPORT_PATH=${qmlImportPath}"
          # Overrides the session-wide QT_QPA_PLATFORMTHEME=kvantum for this
          # service only. Kvantum is a widget *style* and gives Qt no icon
          # theme, so QIcon resolves nothing and system tray icons render as
          # the magenta "missing image" placeholder. The gtk3 platform theme
          # reads gtk-icon-theme-name out of ~/.config/gtk-3.0/settings.ini and
          # makes the whole icon theme available. Quickshell draws its own QML
          # UI and uses no Qt widget styling, so nothing is lost by not using
          # Kvantum here. Needs the correctly-cased theme name in gtk.nix --
          # with either half missing, icon lookup still fails.
          "QT_QPA_PLATFORMTHEME=gtk3"
        ];
        ExecStart = lib.getExe quickshell;
        Restart = "on-failure";
        RestartSec = 3;
        # Only kill quickshell itself on stop/restart, not apps launched from
        # the dock. Dock apps (Quickshell.execDetached) inherit this service's
        # cgroup; the default KillMode=control-group would take them down with
        # a `systemctl restart`.
        KillMode = "process";
      };

      Install = {
        WantedBy = ["hyprland-session.target"];
      };
    };
  };
}
