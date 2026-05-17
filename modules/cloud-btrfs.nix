{ pkgs, hostname, modulesPath, ... }:
{
  imports = [
    # Generic KVM/QEMU guest profile. Swap for a provider-specific profile
    # if needed (see cloud-ext4.nix for the list of alternatives).
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = hostname;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.cpu.intel.updateMicrocode = false;
  hardware.cpu.amd.updateMicrocode = false;

  time.timeZone = "Etc/UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  users.mutableUsers = false;
  users.users.admin = {
    isNormalUser = true;
    description = "Default admin user";
    extraGroups = [ "wheel" ];
    hashedPasswordFile = "/var/lib/secrets/admin.hash";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA...REPLACE_WITH_YOUR_KEY... user@host"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA...REPLACE_WITH_YOUR_KEY... user@host"
  ];

  networking.useDHCP = true;
  networking.firewall.enable = true;

  environment.systemPackages = with pkgs; [
    git vim curl wget tmux htop
    btrfs-progs compsize
  ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  system.stateVersion = "25.11";
}
