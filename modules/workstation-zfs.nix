{ pkgs, hostname, config, ... }:
{
  networking.hostName = hostname;
  # ZFS requires a stable 8-char hex hostId, unique per machine.
  # Derived from the hostname for determinism across rebuilds.
  networking.hostId = builtins.substring 0 8 (builtins.hashString "md5" hostname);

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.systemd.enable = true;
  boot.initrd.systemd.tpm2.enable = true;
  boot.initrd.availableKernelModules = [ "tpm_tis" "tpm_crb" ];

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  # Use the latest kernel ZFS supports — OpenZFS lags mainline by weeks.
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
    autoSnapshot = {
      enable = true;
      flags = "-k -p --utc";
    };
  };

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
  users.users.admin = {
    isNormalUser = true;
    description = "Default admin user";
    extraGroups = [ "wheel" "networkmanager" ];
    hashedPasswordFile = "/var/lib/secrets/admin.hash";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAA...REPLACE_WITH_YOUR_KEY... user@host"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA...REPLACE_WITH_YOUR_KEY... user@host"
  ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  environment.systemPackages = with pkgs; [
    git vim curl wget tmux htop
    cryptsetup tpm2-tools
    zfs
  ];

  systemd.services.tpm2-luks-enroll = {
    description = "Auto-enroll TPM2 for LUKS unlock on first boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "!/var/lib/tpm2-luks-enrolled";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ tpm2-tools cryptsetup systemd util-linux gawk coreutils ];
    script = ''
      set -e
      LUKS_DEVICE=$(lsblk -o NAME,FSTYPE -lpn | awk '$2 == "crypto_LUKS" { print $1; exit }')
      if [ -z "$LUKS_DEVICE" ]; then
        echo "No LUKS device found; skipping enrollment"
        exit 0
      fi
      if [ ! -f /var/lib/secrets/luks.key ]; then
        echo "No keyfile at /var/lib/secrets/luks.key; skipping enrollment"
        exit 0
      fi
      systemd-cryptenroll \
        --tpm2-device=auto \
        --tpm2-pcrs=0+2+7+12 \
        --unlock-key-file=/var/lib/secrets/luks.key \
        "$LUKS_DEVICE"
      shred -u /var/lib/secrets/luks.key 2>/dev/null || rm -f /var/lib/secrets/luks.key
      touch /var/lib/tpm2-luks-enrolled
    '';
  };

  system.stateVersion = "25.11";
}
