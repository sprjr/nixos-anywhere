{ pkgs, hostname, modulesPath, config, ... }:
{
  imports = [
    # Generic KVM/QEMU guest profile. Swap for a provider-specific profile
    # if needed (see cloud-ext4.nix for the list of alternatives).
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = hostname;
  # ZFS requires a stable 8-char hex hostId, unique per machine.
  networking.hostId = builtins.substring 0 8 (builtins.hashString "md5" hostname);

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  # Pin to a kernel ZFS supports — OpenZFS lags mainline by weeks.
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      enable = true;
      flags = "-k -p --utc";
    };
  };

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
    zfs
  ];

  system.stateVersion = "25.11";
}
