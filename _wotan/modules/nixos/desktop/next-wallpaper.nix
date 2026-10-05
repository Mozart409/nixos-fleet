{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  options.desktop.nextWallpaper = {
    enable = lib.mkEnableOption "next-wallpaper script with history and notifications";
    wallpaperDir = lib.mkOption {
      type = lib.types.path;
      default = "${config.users.users.${username}.home}/Pictures/Wallpapers";
      description = "Directory containing wallpapers";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "${config.users.users.${username}.home}/.local/state/wallpaper-rotator";
      description = "Directory for state files (queue, history)";
    };
  };

  config = lib.mkIf config.desktop.nextWallpaper.enable {
    environment.systemPackages = let
      nextWallpaperScript = pkgs.writeShellScriptBin "next-wallpaper" ''
        set -euo pipefail

        wallpaperDir="${config.desktop.nextWallpaper.wallpaperDir}"
        stateDir="${config.desktop.nextWallpaper.stateDir}"
        queueFile="$stateDir/queue.txt"
        historyFile="$stateDir/history.txt"
        currentFile="$stateDir/current.txt"
        forwardFile="$stateDir/forward.txt"
        lockFile="$stateDir/.lock"
        maxHistory=50

        show_notification() {
          local wallpaper="$1"
          local filename
          filename="$(${pkgs.coreutils}/bin/basename "$wallpaper")"
          ${pkgs.libnotify}/bin/notify-send -t 2000 -i "$wallpaper" "Wallpaper" "$filename" || true
        }

        build_queue() {
          mkdir -p "$stateDir"

          ${pkgs.findutils}/bin/find "$wallpaperDir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \) -print0 \
            | ${pkgs.coreutils}/bin/shuf -z \
            | while IFS= read -r -d "" file; do printf '%s\n' "$file"; done \
            > "$queueFile"

          if [ ! -s "$queueFile" ]; then
            rm -f "$queueFile"
            return 1
          fi
        }

        reset_queue() {
          rm -f "$queueFile" "$historyFile" "$currentFile" "$forwardFile"
          echo "Queue and history reset. Next call will reshuffle all wallpapers."
          exit 0
        }

        save_current() {
          local wallpaper="$1"
          mkdir -p "$stateDir"
          echo "$wallpaper" > "$currentFile"
        }

        push_forward() {
          local wallpaper="$1"
          mkdir -p "$stateDir"
          echo "$wallpaper" >> "$forwardFile"
        }

        pop_forward() {
          if [ ! -s "$forwardFile" ]; then
            return 1
          fi
          ${pkgs.coreutils}/bin/tail -n 1 "$forwardFile"
          ${pkgs.gnused}/bin/sed -i '$ d' "$forwardFile"
          return 0
        }

        show_previous() {
          if [ ! -s "$historyFile" ]; then
            echo "No previous wallpaper in history" >&2
            exit 1
          fi

          if [ -f "$currentFile" ]; then
            current="$(${pkgs.coreutils}/bin/cat "$currentFile")"
            if [ -f "$current" ]; then
              push_forward "$current"
            fi
          fi

          wallpaper="$(${pkgs.coreutils}/bin/tail -n 1 "$historyFile")"

          if [ ! -f "$wallpaper" ]; then
            echo "Previous wallpaper no longer exists: $wallpaper" >&2
            ${pkgs.gnused}/bin/sed -i '$ d' "$historyFile"
            exit 1
          fi

          ${pkgs.gnused}/bin/sed -i '$ d' "$historyFile"
          save_current "$wallpaper"

          if [ $# -eq 0 ]; then
            set -- --transition-type random
          fi

          show_notification "$wallpaper"
          exec ${inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww}/bin/awww img "$wallpaper" "$@"
        }

        add_to_history() {
          local wallpaper="$1"
          mkdir -p "$stateDir"
          echo "$wallpaper" >> "$historyFile"

          local count
          count="$(${pkgs.coreutils}/bin/wc -l < "$historyFile")"
          if [ "$count" -gt "$maxHistory" ]; then
            ${pkgs.coreutils}/bin/tail -n "$maxHistory" "$historyFile" > "$historyFile.tmp"
            mv "$historyFile.tmp" "$historyFile"
          fi
        }

        get_next_wallpaper() {
          while [ -s "$queueFile" ]; do
            wallpaper="$(${pkgs.coreutils}/bin/head -n 1 "$queueFile")"
            ${pkgs.coreutils}/bin/tail -n +2 "$queueFile" > "$queueFile.tmp" || true

            if [ -s "$queueFile.tmp" ]; then
              mv "$queueFile.tmp" "$queueFile"
            else
              rm -f "$queueFile.tmp" "$queueFile"
            fi

            if [ -f "$wallpaper" ]; then
              echo "$wallpaper"
              return 0
            fi
          done

          return 1
        }

        if [ "$#" -gt 0 ] && [ "$1" = "--reset" ]; then
          reset_queue
        fi

        if [ "$#" -gt 0 ] && [ "$1" = "--previous" ]; then
          shift
          show_previous "$@"
        fi

        exec 200>"$lockFile"
        ${pkgs.flock}/bin/flock -x 200

        if [ -s "$forwardFile" ]; then
          wallpaper="$(${pkgs.coreutils}/bin/tail -n 1 "$forwardFile")"
          ${pkgs.gnused}/bin/sed -i '$ d' "$forwardFile"

          if [ -f "$wallpaper" ]; then
            if [ -f "$currentFile" ]; then
              current="$(${pkgs.coreutils}/bin/cat "$currentFile")"
              if [ -f "$current" ]; then
                add_to_history "$current"
              fi
            fi

            save_current "$wallpaper"

            if [ $# -eq 0 ]; then
              set -- --transition-type random
            fi

            show_notification "$wallpaper"
            exec ${inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww}/bin/awww img "$wallpaper" "$@"
          fi
        fi

        if [ -f "$currentFile" ]; then
          current="$(${pkgs.coreutils}/bin/cat "$currentFile")"
          if [ -f "$current" ]; then
            add_to_history "$current"
          fi
        fi

        rm -f "$forwardFile"

        if [ ! -s "$queueFile" ]; then
          if ! build_queue; then
            echo "next-wallpaper: No wallpapers found in $wallpaperDir" >&2
            exit 1
          fi
        fi

        wallpaper=""
        while true; do
          if ! wallpaper="$(get_next_wallpaper)"; then
            if ! build_queue; then
              echo "next-wallpaper: No valid wallpapers found in $wallpaperDir" >&2
              exit 1
            fi
            continue
          fi
          break
        done

        save_current "$wallpaper"

        if [ $# -eq 0 ]; then
          set -- --transition-type random
        fi

        show_notification "$wallpaper"
        exec ${inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww}/bin/awww img "$wallpaper" "$@"
      '';
    in [
      nextWallpaperScript
      (pkgs.writeShellScriptBin "previous-wallpaper" ''
        exec ${nextWallpaperScript}/bin/next-wallpaper --previous "$@"
      '')
    ];
  };
}
