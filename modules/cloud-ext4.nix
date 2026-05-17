{ pkgs, hostname, modulesPath, ... }:
{
  imports = [
    # Generic KVM/QEMU guest profile. Works on Hetzner, DigitalOcean, Linode,
    # Vultr, OVH, generic OpenStack, and self-hosted libvirt/QEMU.
    # For provider-specific behavior swap this import for one of:
    #   (modulesPath + "/virtualisation/amazon-image.nix")
    #   (modulesPath + "/virtualisation/google-compute-image.nix")
    #   (modulesPath + "/virtualisation/digital-ocean-config.nix")
    #   (modulesPath + "/virtualisation/azure-image.nix")
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

  # No TPM2 by default on cloud VMs. Enable only if your hypervisor
  # exposes a vTPM (AWS NitroTPM, GCP Shielded VMs, Azure Trusted Launch,
  # libvirt with swtpm). See README.

  # Hypervisor handles microcode; do not waste boot time on it.
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
  ];

  system.stateVersion = "25.11";
}
