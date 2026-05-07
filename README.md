# nixos-anywhere workstation flake

Deploys encrypted NixOS workstations from a Nix-enabled source machine to a target booted from the NixOS installer ISO. Uses disko for partitioning, nixos-facter for hardware detection, and TPM2 for disk auto-unlock.

**Disk layout:**
```
GPT
├── p1: 2 GiB    FAT32   /boot       (EFI)
├── p2: 16 GiB   swap    randomEncryption
└── p3: rest     LUKS2 → ext4   /    (TPM2 auto-unlock + passphrase fallback)
```

## Prerequisites

Source machine requires `nix-command` and `flakes` enabled, plus SSH access to the target.

## Customize before use

In `modules/workstation.nix`, replace:
- `REPLACE_WITH_YOUR_KEY` — your SSH public key (two occurrences: user + root)
- `users.users.admin` — rename to your preferred username
- `time.timeZone`, locale, desktop environment as needed

In `flake.nix`, update `diskDevice` in the `mkHost` call to match the target disk (`lsblk` on target to confirm).

## One-time source setup

```bash
mkdir -p extra-files/var/lib/secrets
mkpasswd -m sha-512 | tr -d '\n' > extra-files/var/lib/secrets/admin.hash
chmod 600 extra-files/var/lib/secrets/admin.hash

nix flake lock
git add -A && git commit -m "initial workstation flake"
```

`extra-files/` is gitignored and deployed out-of-band via `--extra-files`. Never commit it.

## Target preparation

On the target (booted from NixOS installer ISO, wired ethernet recommended, but I tested it successfully without):

```bash
sudo systemctl start sshd
sudo passwd nixos
```

From source, push your key to avoid password prompts during deploy:

```bash
ssh-copy-id -o PreferredAuthentications=password -o IdentitiesOnly=yes nixos@<target-ip>
```

## Deploy

```bash
systemd-ask-password "LUKS passphrase: " | tr -d '\n' > /tmp/disko.key
chmod 600 /tmp/disko.key

nix run github:nix-community/nixos-anywhere -- \
  --flake .#ws-test \
  --target-host nixos@<target-ip> \
  --disk-encryption-keys /tmp/disko.key /tmp/disko.key \
  --extra-files ./extra-files \
  --generate-hardware-config nixos-facter ./hosts/ws-test/facter.json

shred -u /tmp/disko.key
```

`hosts/ws-test/facter.json` is written back to source. Commit it if the repo is private; leave it gitignored if public.

## First boot + TPM2 enrollment

Enter the LUKS passphrase at first boot, then enroll TPM2:

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 /dev/nvme0n1p3
sudo systemctl reboot
```

Rotate the recovery passphrase (the install-time key was on your source machine):

```bash
sudo cryptsetup luksChangeKey /dev/nvme0n1p3
```

TPM2 unlock will fail after firmware/bootloader/initrd changes — boot with the passphrase, wipe and re-enroll:

```bash
sudo systemd-cryptenroll --wipe-slot=tpm2 /dev/nvme0n1p3
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 /dev/nvme0n1p3
```

Optional — add a PIN to the TPM2 slot (defense in depth against cold-boot attacks):

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7+12 --tpm2-with-pin=yes /dev/nvme0n1p3
```

## Adding hosts

In `flake.nix`, add an `mkHost` entry:

```nix
ws-002 = mkHost { hostname = "ws-002"; diskDevice = "/dev/sda"; };
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
nixos-rebuild switch --flake .#ws-test --target-host root@<target-ip> --use-remote-sudo
```

## Notes

- `passwordFile` on the disko LUKS block is consumed only during `luksFormat` and is not written to `/etc/crypttab`. Do not use `settings.keyFile` — it is written to crypttab and will break boot since `/tmp/disko.key` does not exist on the installed system.
- Do not pass `--ssh-option PreferredAuthentications=password` to `nixos-anywhere`. It applies to all internal SSH calls including the root login step, which has no password on the live installer.
- For secrets management beyond `--extra-files`, see [sops-nix](https://github.com/Mic92/sops-nix) or [agenix](https://github.com/ryantm/agenix).

Open an issue if something is broken.
