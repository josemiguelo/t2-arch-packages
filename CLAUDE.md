# Working on the KaiT2en → Omarchy port

Context for Claude sessions (and people) picking this work up. The owner runs it on a
MacBookPro16,1 (16" 2019, T2) named `t2-macbook-omarchy`, on Omarchy's **edge** channel
(permanently), beside macOS. Read this before acting; the dotfiles' `docs/t2-macbook.md`
is the machine-side companion.

## The system

T2 Macs run Omarchy's stock kernel, `linux-omarchy`, with
[KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora)'s T2 drivers built by DKMS, instead of
`linux-t2` from `[arch-mact2]`. Five repos, all the owner's:

| Repo | Role | After a reinstall, at |
|---|---|---|
| `josemiguelo/t2-arch-packages` (this) | PKGBUILDs; the signed pacman repo (release tag `repo`); `bin/kait2en-sync` | `~/Repos/gh/josemiguelo/t2-arch-packages/all_worktrees/main` |
| `josemiguelo/omarchy` (fork), branch `t2-kait2en` | `install/hardware/apple/fix-t2.sh` (installs the packages, initramfs, kernel args, Wi-Fi firmware service), `install/hardware/pacman.sh` (adds the repo), manual | `~/Repos/gh/josemiguelo/omarchy/all_worktrees/t2-kait2en` (`upstream` = omacom, push disabled) |
| `josemiguelo/omarchy-iso` (fork), branch `t2-kait2en` | installer picks `linux-omarchy` on T2, build trusts the repo key, installer populates hardware keyrings in a transient unit | `~/Repos/gh/josemiguelo/omarchy-iso/all_worktrees/t2-kait2en` |
| `josemiguelo/.dotfiles` (chezmoi + loadout) | `loadouts/.etc/t2/` (the machine's T2 setup), `loadouts/.repos/.loadout/kait2en-dev.sh` (this dev setup), `docs/t2-macbook.md` | `~/.local/share/chezmoi` |
| `kaiT2en/KaiT2en-Fedora` (upstream, read-only) | the drivers and tools | `~/Repos/gh/kaiT2en/KaiT2en-Fedora` |

The loadout's `bare-repos` + `kait2en-dev` (machine `t2-macbook-omarchy`) recreate all of it on
a fresh install, plus `omacom/omarchy-pkgs`, `nutanix/libvfio-user` (built), the signing key
from 1Password (item `kait2en`, Personal vault) and the daily `kait2en-sync.timer`.

Packages (README has the test results): `t2bce-stack-dkms`, `t2smc-dkms`, `t2sbs-dkms`,
`t2smp-dkms`, `t2thunderbolt-dkms`, `t2-precision-trackpad-dkms`, `t2-bluetooth-dkms`,
`t2-fan-control`, `t2bce-audio-ucm`, `t2-dkms-guard`, `t2-arch-packages-keyring`. Arch's own
`linux-apfs-rw-dkms` (`[extra]`) gives the firmware fetcher APFS. Signing key
`077D 8295 CCF8 34D3 F5EC  25F7 0506 B72C 34EB 162F` (passphrase in the same 1Password item).

## Where it stands (2026-11-10)

Omarchy is installed on the real Mac from the ISO built from both `t2-kait2en` branches,
**into free space beside macOS** (p2 macOS APFS kept, p3 `OMARCHY_EFI`, p4 LUKS + btrfs), on
stock `linux-omarchy` with every KaiT2en DKMS module built; `linux-t2` is not installed.
The dotfiles' bootstrap has run.

**The real-Mac install found three bugs the fake-T2 VM test can't** (fixed in the
`omarchy` fork's `t2-kait2en` worktree, not yet committed or in a rebuilt ISO):
1. `fix-fkeys.sh` → `omarchy-keyboard-toprow` wrote `fnmode` to `/sys`, which is read-only
   in the installer's chroot; under `set -e` that stopped "Configuring system". The install
   was finished by hand from the live ISO (chroot), which skipped the final `@factory`
   snapshot. Fix: skip the live write where `/sys` isn't writable (test in
   `keyboard-toprow-test.sh`).
2. The same `fix-fkeys.sh` wrote `omarchy-toprow.conf` with `fnmode=1` on the T2 keyboard,
   overriding the dotfiles' default mode 3 (Fn+arrows). Fix: `fix-fkeys.sh` skips T2 Macs
   (`106b:1801/1802`; test in `apple-silicon-quirks-test.sh`). Note `lspci | grep -q` under
   `pipefail` reads as "no match" (SIGPIPE): use `grep … >/dev/null`, as `fix-t2.sh` does.
3. `t2-wifi-firmware.service`'s `ExecStartPost=modprobe -r brcmfmac` failed: `brcmfmac_wcc`
   holds it. The fetcher already reloads in the right order; the line is gone. The dotfiles'
   `bcm-firmware.sh` had the same bug.

**Post-install checks:**
1. Wi-Fi: ✓ fetched off the macOS volume (BCM4364, `brcmfmac4364b3-pcie`); Bluetooth ✓.
2. `loadout status`: T2 items done (`t2-kernel-args`, `t2-bcm-firmware`, `t2-boot-clock`,
   `t2-gmux-backlight`, `t2-render-gpu`, `kait2en-dev`) except `t2-hid-apple-keyboard`,
   pending on bug 2's leftover `omarchy-toprow.conf` until that file is removed.
3. Internal keyboard and trackpad: drivers load on the installed system; owner to confirm.
4. The first `linux-omarchy` upgrade through `t2-dkms-guard`: not yet.
5. Fans: `t2-fan-control` active, 80 °C target; idle fine, not yet tried under load.
6. Charge limit: not yet set (`charge_control_end_threshold` is 100).

Next: rebuild the ISO with the fixes and rerun the fake-T2 test; the `/sys` bug is
covered only by the shell test, since the VM has no `hid_apple`.

## How the owner works

- Clone with `gclone` (zsh function, `~/.config/zsh/plugins/repos/repos.plugin.zsh`), into
  `~/Repos/<host>/<owner>/<repo>`; non-interactively: `zsh -c 'source …; gclone <url> </dev/null'`
  (no TTY → normal clone, not bare). Don't create GitHub forks or publish unless asked.
- Open a tmux window (`tmux new-window -d -t "<session>:" -n <name> -c <path>`) for every repo,
  worktree or folder touched, as soon as it's touched; check for an existing one first.
- Dotfiles: their `AGENTS.md` rules: commit or push only when asked in that turn ("go" isn't
  asking); never commit `machines/state/*` (that's `loadout sync`'s); keep `loadout compile`
  warnings clean; public repo, no secrets.
- KaiT2en: its trademark forbids its name or logo on published forks (the repo name and the
  removed wordmark follow that; attribution stays, the license requires it); its README rejects
  AI-written PRs and issues, so anything going upstream there is the owner's to write.
- Claude Code's auto mode blocks building third-party code and `docker stop`: hand those
  commands to the owner.

## Procedures

- **KaiT2en updates**: `bin/kait2en-sync check` (per-package upstream commits, plus
  `scripts/fedora` changes to port to `fix-t2.sh` by hand), `apply` (re-pin, build, sign, test
  DKMS against the newest headers, publish after asking), `kernel` (all DKMS packages vs the
  newest `linux-omarchy-headers`), `notify` (the timer's). `apply` hasn't had a real run yet.
- **Release by hand** (README, "Build and release"): sign with the key; `repo-add --sign`;
  release assets can't be symlinks (copy `.db`/`.files` and their `.sig` as real files); GitHub's
  CDN serves the old database for about a minute after `--clobber`. The local work dir is
  `~/.cache/t2-arch-packages`; `/tmp` (Claude's scratchpad) is wiped by every reboot.
- **ISO**: in the omarchy-iso worktree, `bin/omarchy-iso-make --keep-pkg-cache --no-boot-offer
  --local-source <omarchy worktree> ~/Repos/gh/omacom/omarchy-pkgs` (~45 min, edge, output
  `release/*-local.iso`; the omarchy package's version label is upstream's pinned commit but
  its files are the worktree's). Test: `VFIO_USER_SERVER=<libvfio-user>/build/samples/gpio-pci-idio-16
  OMARCHY_PATH=<omarchy worktree> bin/omarchy-iso-test <iso> --fake-pci 106b:1802:088000
  --no-preview` (~40 min; `--reuse-base --keep-running` then ssh `omarchy@127.0.0.1 -p 2222`
  with the run's `id_ed25519`). Expected VM-only failures: `t2-wifi-firmware` (no macOS volume)
  and `systemd-modules-load` (`t2bce_vhci` EPROBE_DEFER: a fake 106b:1802 has no BCE). Write a
  stick raw (`dd` + compare), never sparse.

## Facts that cost time to learn

- `t2_precision_trackpad` must load before `t2bce_vhci` (first in initramfs MODULES), or
  hid-apple takes the trackpad's mouse interface. It only claims that interface, so hid-apple
  keeps the keyboard (and the owner's `hid_apple` swaps).
- Stock `btbcm` drops these Macs' LE advertisements ("unknown advertising packet type"):
  `t2-bluetooth-dkms` rebuilds btbcm/hci_uart/hci_bcm4377 from kernel.org 7.2.15 with KaiT2en's
  patches 0002/0012/0013/0021/0024; `BUILD_EXCLUSIVE_KERNEL="^7\.2\.…"`, so on 7.3 its sources
  move by hand. linux-omarchy is plain kernel.org (no stable-review patch); its own Bluetooth
  patches touch only btusb/btintel*, which aren't replaced.
- The fetcher needs APFS (linux-t2 builds it in, linux-omarchy doesn't), and during an ISO
  install its post-install runs in a chroot whose modprobe targets the live ISO's kernel: hence
  `t2-wifi-firmware.service` on the installed system's boots.
- During an ISO install the installer builds the target's pacman keyring in a background unit
  and assumes nothing touches it: a keyring package's post-install `--populate` broke the install,
  so `fix-t2.sh` installs it with `--noscriptlet` when `OMARCHY_FIRST_INSTALL=1`.
- Kernel args `pci=noaer pcie_ports=compat` without `pm_async=off` (+ t2smp) took the wake from
  ~16 s to ~1 s; Omarchy #6559/#6562 had swapped them for `pm_async=off` from KaiT2en's older
  args. Limine's `KERNEL_CMDLINE["<kernel>"]` replaces the default cmdline (dropping the LUKS and
  root args), it doesn't add to it.
- printk/journal timestamps are unreliable across S3 on this Mac; time resume with
  `echo 1 > /sys/power/pm_print_times` (per-device usecs).
- `t2-fan-control` saves its config at every start; upstream's 45 °C system target pins a dGPU
  model's fans at 100%. The T2 SMC keeps manual fan mode across reboots (hand back: `0` to each
  `fanN_target`).
- On linux-omarchy, t2smc is rtc1 (the ACPI TAD moved to rtc2); `t2-boot-clock` picks by name.
- Omarchy: boots UKIs (the initramfs is the `.initrd` section of `/boot/EFI/Linux/*.efi`);
  `xhci_pci`, `usbhid`, `hid_generic` are built in; its pacman guard needs
  `OMARCHY_ALLOW_DIRECT_PACMAN=1` for a direct `-Syu`; the user password is the LUKS password;
  `omarchy refresh pacman` rewrites pacman.conf (the loadout's hook re-adds the repo).
- A local `pacman -U` of a package with a `.sig` beside it checks the signature and looks the
  key up on keyservers (it isn't on any): add the key first.
- `op item edit` reads dots in field names as section.field: escape them (`name\.ext[file]=`).

## Roadmap

After the checks above, in order of value: KaiT2en's `brcmfmac` Wi-Fi patches (same pattern as
`t2-bluetooth-dkms`; one firmware timeout after a resume was seen), the `16_1` speaker DSP
profile (PipeWire filter chain; needs lsp-plugins and lv2-bankstown), packaging the firmware
fetcher here to drop `[arch-mact2]` from installed systems, then the dGPU power work (`t2gmux`
+ KaiT2en's amdgpu runtime-PM patches, two specific to MacBookPro16,1; review the loadout's
`t2-gmux-backlight` and `t2-render-gpu` with it), then `t2touchbar` (replaces hid_apple: the
loadout's `t2-hid-apple-keyboard` swaps move with it), `t2_trackpad_actuator`, and the rest
(Touch ID, Sidecar, AirDrop). Also: make `t2-dkms-guard` warn when a kernel skips a package,
and boot the live ISO on linux-omarchy instead of linux-t2. KaiT2en's recent `scripts/fedora`
changes to review: `d46fc8e` (patched i915 with Apple PSR and gmux brightness restore) and
`8de9546` (t2-truetone).
