{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.nixpkgs.follows = "nixpkgs";
  inputs.nixos-facter-module.url = "github:numtide/nixos-facter-modules";

  outputs =
    {
      nixpkgs,
      disko,
      nixos-facter-modules,
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

      # Generic 'catch-all' starter configuration with facter
      nixosConfiguration.nixos-starter-facter = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
	modules = [
	  disko.nixosModules.disko
	  ./configuration.nix
	  nixos-facter-modules.nixosModules.facter
	  {
	    config.facter.reportPath =
	      if builtins.pathExists ./facter.json then
	        ./facter.json
	      else
	        throw "Have you forgotten to run nixos-anywhere with `--generate-hardware-config nixos-facter ./facter.json`?";
	  }
	];
      };
    };
}
