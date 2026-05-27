{ diskDevice, ... }:
{
  disko.devices.disk.main = {
    device = diskDevice;
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            passwordFile = "/tmp/disko.key";
            settings = {
              crypttabExtraOpts = [
                "tpm2-device=auto"
                "discard"
                "no-read-workqueue"
                "no-write-workqueue"
              ];
            };
            content = {
              type = "btrfs";
              extraArgs = [ "-L" "nixos" "-f" ];
              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [ "compress=zstd:3" "noatime" "ssd" "discard=async" ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [ "compress=zstd:3" "noatime" "ssd" "discard=async" ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd:3" "noatime" "ssd" "discard=async" ];
                };
                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [ "compress=zstd:3" "noatime" "ssd" "discard=async" ];
                };
                "@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = [ "compress=zstd:3" "noatime" "ssd" "discard=async" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
