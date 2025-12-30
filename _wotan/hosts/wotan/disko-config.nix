{
  disko.devices = {
    disk = {
      sda = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            storage = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "bcachefs";
                mountpoint = "/mnt/storage";
                extraArgs = [
                  "--compression=zstd"
                ];
                mountOptions = [
                  "compress=zstd"
                ];
              };
            };
          };
        };
      };
    };
  };
}
