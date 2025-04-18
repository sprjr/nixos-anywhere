{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      nixpkgs,
      disko,
      ...
    }:
    {
      # Generic 'catch-all' starter configuration
      # nixos-anywhere --flake .#nixos-starter --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      nixosConfigurations.nixos-starter = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
	modules = [
	  disko.nixosModules.disko
	  ./configuration.nix
	  ./hardware-configuration.nix
	];
      };
    };
}
