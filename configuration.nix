{ modulesPath, lib, pkgs, ... }:

{
  # This assumes a non virtualized system -- virtualized systems may require qemu or other imports
  imports = [
    ./ext4-config.nix # disko configuration -- make sure to check the target disk
  ];
  boot.loader.grub = {
    # disko will add all devices that have a EF02 partition to the list
    # devices [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.git
    pkgs.vim
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    # public ssh key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYxyYpBB8K35/1+c22hBDV6mQFkqvxJeBC/SWs8Yyh+ patrick@macnnix"
  ];

  system.stateVersion = "24.05";
}
