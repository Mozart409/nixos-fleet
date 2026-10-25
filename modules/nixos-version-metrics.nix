{
  config,
  lib,
  pkgs,
  ...
}: let
  textfileDir = "/var/lib/node_exporter/textfile";

  # Activation scripts can run with a minimal PATH that doesn't reliably
  # include environment.systemPackages (gnused is installed system-wide, but
  # that alone isn't enough here) -- e.g. `sudo switch-to-configuration
  # switch` inherits sudo's sanitized `secure_path`, not
  # /run/current-system/sw/bin. Surfaced live as "sed: command not found"
  # during a manual activation on 2026-08-20 (uncertain whether a normal
  # colmena-driven apply, running as root without going through sudo,
  # would hit this the same way -- but referencing the store path directly is
  # the standard, unconditionally-correct pattern for anything invoked from
  # system.activationScripts regardless).
  # The generation number lives in the profile link (system-N-link), NOT in
  # /run/current-system: that resolves to .../<hash>-nixos-system-<host>-<version>,
  # and the old `sed 's/.*-system-//'` on it produced "<host>-<version>" -- a
  # non-numeric sample that made node_exporter reject the whole nixos.prom
  # (node_textfile_scrape_error=1 on every host, no nixos_* metric ever
  # scraped; found 2026-09-15).
  generationScript = ''
    gen=$(readlink /nix/var/nix/profiles/system 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/^system-\([0-9]*\)-link$/\1/p')
    echo "''${gen:-0}"
  '';

  # One nixos_kernel_info sample for /run/<system>/kernel. "current" is the
  # system being activated ($systemConfig, see the activation-order trap below).
  # "booted" falls back to it while /run/booted-system is missing: /run is a
  # tmpfs, so the link is gone at boot, and the boot activation is the booted
  # system. Version comes from the store path, .../<hash>-linux-<version>/bzImage.
  kernelInfoScript = ''
    kernel_info() {
      path=$(readlink -f "$2/kernel" 2>/dev/null) || path=unknown
      version=$(echo "$path" | ${pkgs.gnused}/bin/sed -n 's|^/nix/store/[^-]*-linux-\([^/]*\)/.*$|\1|p')
      echo "nixos_kernel_info{system=\"$1\",version=\"''${version:-unknown}\",path=\"$path\"} 1"
    }
    current=''${systemConfig:-/run/current-system}
    booted=/run/booted-system
    [ -e "$booted" ] || booted=$current
    kernel_info current "$current"
    kernel_info booted "$booted"
  '';
in {
  # Enable the node_exporter textfile collector
  services.prometheus.exporters.node.extraFlags = [
    "--collector.textfile.directory=${textfileDir}"
  ];

  # Ensure the textfile directory exists
  systemd.tmpfiles.rules = [
    "d ${textfileDir} 0755 root root -"
  ];

  # Write NixOS version metrics on every activation so node_exporter exposes
  # them at the /metrics endpoint. Uses atomic write (temp file + mv) so
  # node_exporter never reads a partially-written file.
  #
  # Activation-order trap: the generated `activate` script re-points
  # /run/current-system only as its LAST step, after every activationScript has
  # run -- so at this point it still names the PREVIOUS generation (that is
  # exactly what the first version of nixos_system_info reported, 2026-09-15).
  # The system being activated is $systemConfig (exported by `activate`, also
  # set at boot); the profile link is already updated by the time we run, so
  # its mtime is the deploy time and survives reboots.
  system.activationScripts.nixosVersionMetrics = {
    text = ''
      mkdir -p ${textfileDir}
      tmp=${textfileDir}/nixos.prom.$$
      kernels=$(${kernelInfoScript})
      cat > "$tmp" <<PROM
      # HELP nixos_info NixOS release and kernel version
      # TYPE nixos_info gauge
      nixos_info{version="${config.system.nixos.release}",kernel_version="${config.boot.kernelPackages.kernel.version}"} 1
      # HELP nixos_system_build_timestamp_seconds Unix timestamp of when the current system generation was set (mtime of the system profile link)
      # TYPE nixos_system_build_timestamp_seconds gauge
      nixos_system_build_timestamp_seconds $(stat -c %Y /nix/var/nix/profiles/system 2>/dev/null || echo 0)
      # HELP nixos_system_generation Current NixOS generation number
      # TYPE nixos_system_generation gauge
      nixos_system_generation $(${generationScript})
      # HELP nixos_system_info Store path of the running system closure (compare against a locally evaluated toplevel)
      # TYPE nixos_system_info gauge
      nixos_system_info{system_path="$(readlink -f "''${systemConfig:-/run/current-system}" 2>/dev/null || echo unknown)"} 1
      # HELP nixos_kernel_info Kernel of /run/current-system and /run/booted-system; they differ until the host reboots
      # TYPE nixos_kernel_info gauge
      $kernels
      PROM
      mv "$tmp" ${textfileDir}/nixos.prom
    '';
    deps = [];
  };
}
