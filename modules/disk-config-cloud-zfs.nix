{ diskDevice, ... }:
{
  disko.devices = {
    disk.main = {
      device = diskDevice;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool.rpool = {
      type = "zpool";
      rootFsOptions = {
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
        mountpoint = "none";
        "com.sun:auto-snapshot" = "false";
      };
      options = {
        ashift = "12";
        autotrim = "on";
      };
      datasets = {
        "root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options."com.sun:auto-snapshot" = "true";
        };
        "home" = {
          type = "zfs_fs";
          mountpoint = "/home";
          options."com.sun:auto-snapshot" = "true";
        };
        "nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options = {
            "com.sun:auto-snapshot" = "false";
            atime = "off";
          };
        };
        "var-log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
          options."com.sun:auto-snapshot" = "false";
        };
      };
    };
  };
}
