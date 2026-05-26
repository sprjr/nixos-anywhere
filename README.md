# nixos-anywhere deployment flake

Deploys NixOS via disko and nixos-anywhere across six variants: three workstation (LUKS-encrypted with TPM2 auto-unlock) and three cloud (unencrypted), in ext4, btrfs, or zfs.

## Deployment matrix

| Target | ext4 | btrfs | zfs |
|--------|------|-------|-----|
| **Workstation** (LUKS + TPM2 auto-unlock) | `ws-ext4` — **tested** ✓ | `ws-btrfs` — **untested** ✓ | `ws-zfs` — **untested** ⚠ |
| **Cloud** (unencrypted, provider at-rest) | `cloud-ext4` — **untested** ⚠ | `cloud-btrfs` — **untested** ⚠ | `cloud-zfs` — **untested** ⚠ |

Pick a variant by passing its name to `--flake .#<variant>` during deploy. Only ext4-workstation has been validated end-to-end. The others compile and follow upstream patterns but the install + first-boot path has not been verified — report results if you exercise them.

## Disk layouts

**Workstation** (all filesystems):
```
GPT
├── p1: 2 GiB    FAT32   /boot       (EFI)
├── p2: 16 GiB   swap    randomEncryption
└── p3: rest     LUKS2 → <ext4 | btrfs subvolumes | zfs datasets>   /
                 TPM2 auto-unlock + passphrase fallback
```

**Cloud** (all filesystems):
```
GPT
├── p1: 1 GiB    FAT32   /boot       (EFI)
└── p2: rest     <ext4 | btrfs subvolumes | zfs datasets>   /
                 (no encryption — relies on provider at-rest)
```

btrfs variants use subvolumes `@root`, `@home`, `@nix`, `@log`, `@snapshots` with zstd compression. zfs variants use a pool `rpool` with datasets `root`, `home`, `nix`, `var-log`. See `modules/disk-config-*.nix` for full details.

## Prerequisites

Source machine: `nix-command` and `flakes` enabled. SSH access to the target.

## Customize before use

In the host module for your chosen variant (e.g. `modules/workstation-ext4.nix`), replace:
- `REPLACE_WITH_YOUR_KEY` — your SSH public key (two occurrences: admin + root)
- `users.users.admin` — rename to your preferred username if desired
- `time.timeZone`, locale, desktop environment as needed

In `flake.nix`, update `diskDevice` in the relevant `mkHost` call to match the target disk (`lsblk` on target to confirm). Defaults: `/dev/nvme0n1` for workstation, `/dev/vda` for cloud.

## One-time source setup

```bash
mkdir -p extra-files/var/lib/secrets
mkpasswd -m sha-512 | tr -d '\n' > extra-files/var/lib/secrets/admin.hash
chmod 600 extra-files/var/lib/secrets/admin.hash

nix flake lock
git add -A && git commit -m "initial flake"
```

`extra-files/` is gitignored and deployed out-of-band via `--extra-files`. Never commit it.

## Target preparation

### Workstation — booted from NixOS installer ISO

**Status: tested.**

Wired ethernet recommended, but I tested it successfully without.
If you don't use a USB installer, you should use ethernet, or configure your system appropriately. When I don't use an installer it loses network when it reboots through the process and it fails.

```bash
sudo systemctl start sshd
sudo passwd nixos
```

From source, push your key to avoid password prompts during deploy:

```bash
ssh-copy-id -o PreferredAuthentications=password -o IdentitiesOnly=yes nixos@<target-ip>
```

### Cloud — provider VM running any Linux

**Status: not yet tested.**

The target needs SSH access with root or passwordless sudo. Whatever Linux the provider gives you (Debian, Ubuntu, Fedora, etc.) works. No further preparation — nixos-anywhere kexecs into the NixOS installer environment automatically during deploy.

## Deploy

### Workstation variants

**Status: ext4 and btrfs tested. zfs untested.**

```bash
systemd-ask-password "LUKS passphrase: " | tr -d '\n' > /tmp/disko.key
chmod 600 /tmp/disko.key

# Also stage the passphrase as a keyfile for first-boot TPM2 auto-enrollment.
cp /tmp/disko.key extra-files/var/lib/secrets/luks.key
chmod 600 extra-files/var/lib/secrets/luks.key

nix run github:nix-community/nixos-anywhere -- \
  --flake .#ws-ext4 \
  --target-host nixos@<target-ip> \
  --disk-encryption-keys /tmp/disko.key /tmp/disko.key \
  --extra-files ./extra-files \
  --generate-hardware-config nixos-facter ./hosts/ws-ext4/facter.json

shred -u /tmp/disko.key
shred -u extra-files/var/lib/secrets/luks.key
```

Replace `ws-ext4` with `ws-btrfs` or `ws-zfs` for the other variants. `hosts/<variant>/facter.json` is written back to source — commit it if private, leave gitignored if public.

### Cloud variants

**Status: all fs-types not yet tested.**

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#cloud-ext4 \
  --target-host root@<target-ip> \
  --extra-files ./extra-files \
  --generate-hardware-config nixos-facter ./hosts/cloud-ext4/facter.json
```

Replace `cloud-ext4` with `cloud-btrfs` or `cloud-zfs`. No LUKS key file needed (no encryption by default). `--target-host` is typically `root@` since most cloud images give you root SSH; use a different user if your provider hands you one with passwordless sudo instead.

## First boot

### Workstation: TPM2 auto-enrollment

**Status: ext4 verified. btrfs and zfs untested.**

Enter the LUKS passphrase at first boot. After boot completes, the `tpm2-luks-enroll` systemd service runs once: locates the LUKS device, reads `/var/lib/secrets/luks.key`, enrolls TPM2 against the LUKS volume, shreds the keyfile, writes `/var/lib/tpm2-luks-enrolled` so it never runs again. Subsequent boots unlock silently.

Verify:

```bash
sudo journalctl -u tpm2-luks-enroll
ls /var/lib/tpm2-luks-enrolled            # exists
ls /var/lib/secrets/luks.key              # should not exist
sudo systemctl reboot                     # next boot unlocks silently
```

If auto-enrollment failed, or you want different PCRs, run it manually:

(Note that omitting "12" from `--tpm2-pcrs=0+2+7+12` removes the systemd-boot/initrd check. Depending on your security tolerance, this may be a nicer experience — less strict, but up to user preference.)

```bash
LUKS_DEVICE=$(lsblk -o NAME,FSTYPE -lpn | awk '$2 == "crypto_LUKS" { print $1; exit }')
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 "$LUKS_DEVICE"
sudo touch /var/lib/tpm2-luks-enrolled    # prevents the service from re-running
sudo systemctl reboot
```

Rotate the recovery passphrase (the install-time key was on your source machine):

```bash
sudo cryptsetup luksChangeKey "$LUKS_DEVICE"
```

TPM2 unlock fails after firmware/bootloader/initrd changes — boot with the passphrase, wipe and re-enroll:

```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 "$LUKS_DEVICE"
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 "$LUKS_DEVICE"
```

Optional — add a PIN to the TPM2 slot (defense in depth against cold-boot attacks):

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --tpm2-with-pin=yes "$LUKS_DEVICE"
```

### Cloud: nothing required

**Status: not yet tested.**

The cloud variants are unencrypted by default. First boot completes without intervention. SSH in and you're done.

## Adding hosts

In `flake.nix`, add an `mkHost` entry. Pick the variant by passing the matching host/disk modules:

```nix
ws-002 = mkHost {
  hostname = "ws-002";
  diskDevice = "/dev/sda";
  hostModule = ./modules/workstation-btrfs.nix;
  diskModule = ./modules/disk-config-workstation-btrfs.nix;
};
```

Create the host directory:

```bash
mkdir -p hosts/ws-002
echo '{ ... }: { }' > hosts/ws-002/default.nix
```

Deploy the same way as above, substituting the new hostname and target IP.

## Subsequent updates

From source:

```bash
nixos-rebuild switch --flake .#<config-name> --target-host root@<target-ip> --use-remote-sudo
```

Switch to a different variant entirely:

```bash
nixos-rebuild switch --flake .#<your-new-variant> --target-host root@<target-ip> --use-remote-sudo
```

## Alternatives covered briefly

### Cloud encryption

**Status: not yet tested.**

Default cloud variants are unencrypted. Two options to add encryption:

1. **LUKS with passphrase at every boot.** Console required for every reboot (use the provider's web console). Copy the `luks` block from `modules/disk-config-workstation-*.nix` into the cloud disk-config, remove `tpm2-device=auto` from `crypttabExtraOpts`. Add `cryptsetup` to packages.
2. **LUKS + vTPM (AWS NitroTPM / GCP Shielded VMs / Azure Trusted Launch / libvirt swtpm).** Matches the workstation flow exactly. Use the workstation variant unchanged on a vTPM-enabled VM; only the disk path changes.

### Per-provider cloud modules

Cloud modules import `(modulesPath + "/profiles/qemu-guest.nix")` by default. For provider-specific driver and agent setup, swap that one import for:

```nix
(modulesPath + "/virtualisation/amazon-image.nix")          # AWS EC2
(modulesPath + "/virtualisation/google-compute-image.nix")  # GCP
(modulesPath + "/virtualisation/digital-ocean-config.nix")  # DigitalOcean
(modulesPath + "/virtualisation/azure-image.nix")           # Azure
```

The generic profile works on Hetzner, DigitalOcean, Linode, Vultr, OVH, and most KVM-backed clouds without modification.

### Desktop environment

Workstation variants enable KDE Plasma 6. To swap for GNOME, replace the `plasma6` and `sddm` lines with:

```nix
services.xserver.desktopManager.gnome.enable = true;
services.displayManager.gdm.enable = true;
```

For a headless workstation, drop the entire `services.xserver`/`services.desktopManager`/`services.displayManager` block.

### Hibernation

`randomEncryption = true` on swap blocks hibernation. For hibernation support, move swap inside the LUKS container (LVM-on-LUKS layout).

## Notes

- `passwordFile` on the disko LUKS block is consumed only during `luksFormat` and is not written to `/etc/crypttab`. Do not use `settings.keyFile` — it is written to crypttab and will break boot since `/tmp/disko.key` does not exist on the installed system.
- Do not pass `--ssh-option PreferredAuthentications=password` to `nixos-anywhere`. It applies to all internal SSH calls including the root login step, which has no password on the live installer.
- ZFS variants set `networking.hostId` deterministically from the hostname via `builtins.hashString`. Required by ZFS, stable across rebuilds.
- ZFS variants pin `boot.kernelPackages` to `latestCompatibleLinuxPackages` because OpenZFS lags mainline by weeks.
- btrfs and zfs variants include monthly auto-scrub services.
- For secrets management beyond `--extra-files`, see [sops-nix](https://github.com/Mic92/sops-nix) or [agenix](https://github.com/ryantm/agenix).

Open an issue if something is broken.
