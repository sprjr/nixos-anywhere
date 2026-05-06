{ pkgs, nixos-anywhere-workstation, ... }:
{
  networking.hostName = nixos-anywhere-workstation;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.tpm2.enable = true;
  boot.initrd.availableKernelModules = [
    "tpm_tis"
    "tpm_crb"
  ];

  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  services.xserver.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  users.mutableUsers = false;
  users.users.patrick = {
    isNormalUser = true;
    description = "Default user";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    hashedPasswordFile = "/var/lib/secrets/default-user.hash";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYxyYpBB8K35/1+c22hBDV6mQFkqvxJeBC/SWs8Yyh+ patrick@macnnix"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYxyYpBB8K35/1+c22hBDV6mQFkqvxJeBC/SWs8Yyh+ patrick@macnnix"
  ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    wget
    tmux
    htop
    cryptsetup
    tpm2-tools
  ];

  system.stateVersion = "25.11";
}
