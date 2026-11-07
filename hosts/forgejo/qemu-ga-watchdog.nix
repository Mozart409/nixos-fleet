{pkgs, ...}: let
  unit = "qemu-guest-agent.service";
in {
  # qemu-ga has pinned a core here in a failing write() loop after the nightly
  # PBS backup (2026-11-03, -06, -07; cause unknown). Restarting clears it but
  # destroys the evidence, so capture first, then restart. Results land in Loki
  # under job="qemu-ga-watchdog". This replaces SustainedHighCPU for this spin:
  # it clears long before that alert's 6h `for`.
  systemd.services.qemu-ga-watchdog = {
    description = "Capture evidence from a spinning qemu-ga, then restart it";
    path = with pkgs; [coreutils gawk strace systemd];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "qemu-ga-watchdog";
      RuntimeDirectoryPreserve = true;
      TimeoutStartSec = "2min";
    };
    script = ''
      state=/run/qemu-ga-watchdog/last
      pid=$(systemctl show -p MainPID --value ${unit})
      if [ "$pid" = 0 ] || [ ! -r "/proc/$pid/stat" ]; then
        rm -f "$state"
        exit 0
      fi

      # utime + stime; comm is "(qemu-ga)", so the field numbers hold.
      ticks=$(awk '{print $14 + $15}' "/proc/$pid/stat")
      now=$(date +%s)
      prev_pid="" prev_ticks="" prev_now=""
      if [ -r "$state" ]; then
        read -r prev_pid prev_ticks prev_now < "$state"
      fi
      printf '%s %s %s\n' "$pid" "$ticks" "$now" > "$state"

      # The average since the last run, not an instant: a short burst during a
      # backup's fs-freeze must never restart the agent.
      if [ "$prev_pid" != "$pid" ] || [ "$now" -le "$prev_now" ]; then
        exit 0
      fi
      # 100 ticks per second, so ticks per second is percent of one core.
      cpu=$(((ticks - prev_ticks) / (now - prev_now)))
      if [ "$cpu" -lt 50 ]; then
        exit 0
      fi

      echo "qemu-ga spin: pid=$pid cpu=$cpu% over $((now - prev_now))s"
      echo "--- syscall summary"
      timeout -s INT 2 strace -c -p "$pid" 2>&1 || true
      echo "--- write() calls with errno and fd path"
      timeout -s INT 2 strace -y -tt -T -e trace=write -s 64 -p "$pid" 2>&1 | head -n 20 || true
      echo "--- open files"
      ls -l "/proc/$pid/fd" || true
      echo "--- kernel stack"
      cat "/proc/$pid/stack" || true
      echo "--- virtio ports"
      ls -l /dev/virtio-ports || true
      echo "--- agent journal"
      journalctl -u ${unit} -n 20 --no-pager || true

      rm -f "$state"
      systemctl restart ${unit}
      echo "qemu-ga spin: restarted ${unit}"
    '';
  };

  systemd.timers.qemu-ga-watchdog = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
    };
  };

  services.loki-logs.units = [
    {
      unit = "qemu-ga-watchdog.service";
      job = "qemu-ga-watchdog";
    }
  ];
}
