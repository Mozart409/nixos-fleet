{
  disko.devices = {
    disk = {
      games = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST2000DM008-2FR102_ZFL5S46T";
        content = {
          type = "gpt";
          partitions = {
            games = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/mnt/games";
                mountOptions = ["nofail" "exec" "user" "users"];
                extraArgs = ["-f"];
              };
            };
          };
        };
      };
    };
  };
}
