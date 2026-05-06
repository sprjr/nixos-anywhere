{
  description = "Workstation deployment flake";

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
        { hostname, diskDevice }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit hostname diskDevice; };
          modules = [
            disko.nixosModules.disko
            nixos-facter-modules.nixosModules.facter
            ./modules/disk-config.nix
            ./modules/workstation.nix
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
        ws-test = mkHost {
          hostname = "ws-test";
          diskDevice = "/dev/nvme0n1";
        };
      };
    };
}
