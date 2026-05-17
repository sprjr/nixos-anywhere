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
        swap = {
          size = "16G";
          content = {
            type = "swap";
            randomEncryption = true;
            priority = 100;
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
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "defaults" "noatime" ];
            };
          };
        };
      };
    };
  };
}
