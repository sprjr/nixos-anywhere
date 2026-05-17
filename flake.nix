{
  description = "Workstation and cloud deployment flake (ext4 / btrfs / zfs)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-facter-modules.url = "github:nix-community/nixos-facter-modules";
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
      nixos-facter-modules,
      ...
    }:
    let
      system = "x86_64-linux";

      mkHost =
        {
          hostname,
          diskDevice,
          hostModule,
          diskModule,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit hostname diskDevice; };
          modules = [
            disko.nixosModules.disko
            nixos-facter-modules.nixosModules.facter
            diskModule
            hostModule
            ./hosts/${hostname}
            (
              { lib, ... }:
              lib.mkIf (builtins.pathExists ./hosts/${hostname}/facter.json) {
                facter.reportPath = ./hosts/${hostname}/facter.json;
              }
            )
          ];
        };
    in
    {
      nixosConfigurations = {
        # Local (workstation) deployments — LUKS + TPM2 auto-unlock
        ws-ext4 = mkHost {
          hostname = "ws-ext4";
          diskDevice = "/dev/nvme0n1";
          hostModule = ./modules/workstation-ext4.nix;
          diskModule = ./modules/disk-config-workstation-ext4.nix;
        };

        ws-btrfs = mkHost {
          hostname = "ws-btrfs";
          diskDevice = "/dev/nvme0n1";
          hostModule = ./modules/workstation-btrfs.nix;
          diskModule = ./modules/disk-config-workstation-btrfs.nix;
        };

        ws-zfs = mkHost {
          hostname = "ws-zfs";
          diskDevice = "/dev/nvme0n1";
          hostModule = ./modules/workstation-zfs.nix;
          diskModule = ./modules/disk-config-workstation-zfs.nix;
        };

        # Cloud deployments — unencrypted (rely on provider at-rest)
        cloud-ext4 = mkHost {
          hostname = "cloud-ext4";
          diskDevice = "/dev/vda";
          hostModule = ./modules/cloud-ext4.nix;
          diskModule = ./modules/disk-config-cloud-ext4.nix;
        };

        cloud-btrfs = mkHost {
          hostname = "cloud-btrfs";
          diskDevice = "/dev/vda";
          hostModule = ./modules/cloud-btrfs.nix;
          diskModule = ./modules/disk-config-cloud-btrfs.nix;
        };

        cloud-zfs = mkHost {
          hostname = "cloud-zfs";
          diskDevice = "/dev/vda";
          hostModule = ./modules/cloud-zfs.nix;
          diskModule = ./modules/disk-config-cloud-zfs.nix;
        };
      };
    };
}
