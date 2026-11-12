# Working on the KaiT2en → Omarchy port

Context for Claude sessions (and people) picking this work up. The owner runs it on a
MacBookPro16,1 (16" 2019, T2) named `t2-macbook-omarchy`, on Omarchy's **stable** channel
(the ISO is built with `--stable`), beside macOS. Read this before acting; the dotfiles' `docs/t2-macbook.md`
is the machine-side companion, and `docs/omarchy-integration.md` explains how the fork's install,
the running system and updates fit together, and how to maintain them.

## The system

T2 Macs run Omarchy's stock kernel, `linux-omarchy`, with
[KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora)'s T2 drivers built by DKMS, instead of
`linux-t2` from `[arch-mact2]`. Five repos, all the owner's:

| Repo | Role | After a reinstall, at |
|---|---|---|
| `josemiguelo/t2-arch-packages` (this) | PKGBUILDs; the signed pacman repo (release tag `repo`); `bin/kait2en-sync` | `~/Repos/gh/josemiguelo/t2-arch-packages/all_worktrees/main` |
| `josemiguelo/omarchy` (fork), branch `t2-kait2en-stable` (its only one, the default) | `install/hardware/apple/fix-t2.sh` (installs the packages, initramfs, kernel args, Wi-Fi firmware service), `install/hardware/pacman.sh` (adds the repo), manual; on Omarchy's stable release commit | `~/Repos/gh/josemiguelo/omarchy/all_worktrees/t2-kait2en-stable` (`upstream` = omacom, push disabled) |
| `josemiguelo/omarchy-iso` (fork), branch `t2-kait2en` | installer picks `linux-omarchy` on T2, build trusts the repo key, installer populates hardware keyrings in a transient unit | `~/Repos/gh/josemiguelo/omarchy-iso/all_worktrees/t2-kait2en` |
| `josemiguelo/.dotfiles` (chezmoi + loadout) | `loadouts/.etc/t2/` (the machine's T2 setup), `loadouts/.repos/.loadout/kait2en-dev.sh` (this dev setup), `docs/t2-macbook.md` | `~/.local/share/chezmoi` |
| `kaiT2en/KaiT2en-Fedora` (upstream, read-only) | the drivers and tools | `~/Repos/gh/kaiT2en/KaiT2en-Fedora` |

The loadout's `bare-repos` + `kait2en-dev` (machine `t2-macbook-omarchy`) recreate all of it on
a fresh install, plus `omacom/omarchy-pkgs`, `nutanix/libvfio-user` (built), the signing key
from 1Password (item `kait2en`, Personal vault) and the daily `kait2en-sync.timer`.

Packages (README has the test results): `t2bce-stack-dkms`, `t2smc-dkms`, `t2sbs-dkms`,
`t2smp-dkms`, `t2thunderbolt-dkms`, `t2-precision-trackpad-dkms`, `t2-bluetooth-dkms`,
`t2-fan-control`, `t2-smc-control`, `t2bce-audio-ucm`, `t2-dsp` (with `bankstown-lv2`, not KaiT2en's),
`t2-dkms-guard`, `t2-arch-packages-keyring`. Arch's own
`linux-apfs-rw-dkms` (`[extra]`) gives the firmware fetcher APFS. Signing key
`077D 8295 CCF8 34D3 F5EC  25F7 0506 B72C 34EB 162F` (passphrase in the same 1Password item).

## Where it stands (2026-11-12)

Reinstalled on 2026-11-11 from a `--stable` ISO built from both `t2-kait2en` branches (the
omarchy fork's `t2-kait2en-stable`), **into free space beside macOS** (p2 macOS APFS kept,
p3 `OMARCHY_EFI`, p4 LUKS + btrfs), on stock `linux-omarchy` 7.2.15 with every KaiT2en DKMS
module built; `linux-t2` is not installed. Every installer phase finished, the `@factory`
snapshot included, and the dotfiles' bootstrap has run. The three bugs the 2026-11-10 install
found (`fix-fkeys.sh`'s `/sys` write and `omarchy-toprow.conf`, the Wi-Fi unit's
`modprobe -r`) are fixed in the fork and didn't come back.

**Checked on the first boots:**
1. Wi-Fi: ✓ on the very first boot. `t2-wifi-firmware.service` fetched the firmware and
   `t2-wifi-reload` brought the card up (the 2026-11-11 first-boot bug is fixed). Bluetooth ✓:
   the Keychron K15 Max and MX Master 3 connect, no "unknown advertising packet type".
2. Internal keyboard, trackpad (with its Force Click device), Touch Bar and T2 audio sinks
   are up on their drivers; multitouch and Force Click not re-tested after this install.
3. Deep sleep: ✓, wakes in ~1 s (owner-tested).
4. Fans: `t2-fan-control` active, 80 °C target; idle fine, not yet tried under load.
5. Charge limit: 85% (the dotfiles' `t2-charge-limit`), with this repo's `t2-smc-control`
   (published 2026-11-12) and its `t2-smc-gaugingd` lifting it for calibration charges.
6. `loadout status`: every T2 item done; pending only what's by hand (`surfingkeys`,
   `android-sdk`).
7. The first `linux-omarchy` upgrade through `t2-dkms-guard`: not yet.

**Fixed after the install** (dotfiles, and the fork's `t2-kait2en-stable`, not yet in an ISO):
NetworkManager retried DHCP every 45 s on the T2's internal
USB network link (`05ac:8233`), now unmanaged by a udev rule; `t2-smc-control` installed and its
daemon enabled by `fix-t2.sh`; `t2-dsp` (speaker DSP). In the dotfiles only: 1Password's own "Start at login" entry
dropped the scale flag at every start (login startup is loadout's now), and `rtkit` was
missing, so PipeWire had no realtime threads (Omarchy lists it for aarch64 only).

Watch: `amdgpu … Fence fallback timer expired on ring sdma0` (twice on 2026-11-12), with the
dGPU power work below.

Next: rebuild the ISO from `t2-kait2en-stable` and rerun the fake-T2 test.

**One branch since 2026-11-12**: this is a personal project and nothing goes upstream, so the
omarchy fork keeps only `t2-kait2en-stable` (its default); `t2-kait2en` (the same commits on
`quattro`, for upstreaming) and the fork's copies of omacom's branches were deleted. Each new
Omarchy stable release means a rebase onto the commit its package is built from, before an ISO.
Upcoming upstream changes are watched through `upstream/quattro` (its migrations), not a branch.

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
- Building third-party code is allowed: the owner's Claude Code user settings allow `makepkg`,
  `cargo build` and `make` (auto mode blocked them before, a CLAUDE.md line can't lift that).
  Publishing (`gh release upload`/`delete-asset`, the release's `repo-add`) and `docker stop`
  still go through the owner.

## Procedures

- **KaiT2en updates wait a month** (the owner's rule, 2026-11-12): KaiT2en ships dangerous
  changes often, so nothing is ported, re-pinned or added until the KaiT2en commit that brings it
  is **at least 30 days old**, and the paths it touches have had **no further real change for 30
  days** (repo-wide sweeps such as lockfile alignment don't count; follow-up "fix"/"revert"
  commits do, and restart the clock). Pin to that commit, not to KaiT2en's HEAD. Before porting,
  read the 30 days of history after it for reverts and fixes, and check its issues. A security fix
  or a fix for a bug this Mac actually hits can go sooner, by the owner's explicit decision only.
  The pins in place on 2026-11-12 (`27fd5c9`, 2026-11-07) predate the rule; they're the tested
  baseline, and the next re-pin follows it.
- **KaiT2en tooling**: `bin/kait2en-sync check` (per-package upstream commits, plus
  `scripts/fedora` changes to port to `fix-t2.sh` by hand), `apply` (re-pin, build, sign, test
  DKMS against the newest headers, publish after asking), `kernel` (all DKMS packages vs the
  newest `linux-omarchy-headers`), `notify` (the timer's). They follow the one-month rule
  (`KAIT2EN_MIN_AGE_DAYS`, default 30; since 2026-11-12): `check` marks each upstream commit
  `eligible`, `waiting` or `sweep` and says when the waiting ones qualify, `apply` pins each package
  to its own eligible commit, never backwards, and `notify` only speaks for eligible updates.
  Sweeps are a heuristic (more than 8 `apps/`/`modules/` folders): `6ddacd9`, a new feature, counts
  as one, so read sweep lines. `apply` hasn't had a real run yet. Until 2026-11-12 `check` saw no
  package at all (a failing `grep` on the keyring's PKGBUILD ended the list under `pipefail`), so
  every "no upstream changes" before then meant nothing.
- **Release by hand** (README, "Build and release"): sign with the key; `repo-add --sign`;
  release assets can't be symlinks (copy `.db`/`.files` and their `.sig` as real files); GitHub's
  CDN serves the old database for about a minute after `--clobber`. The local work dir is
  `~/.cache/t2-arch-packages`; `/tmp` (Claude's scratchpad) is wiped by every reboot.
- **ISO**: a stable build (`--stable`) from `t2-kait2en-stable`, in the omarchy-iso worktree:
  `bin/omarchy-iso-make --keep-pkg-cache --no-boot-offer --local-source <omarchy worktree>
  ~/Repos/gh/omacom/omarchy-pkgs --stable` (~45 min, output `release/*-local-stable.iso`; the
  dotfiles' `docs/t2-macbook.md` has the full command; the omarchy package's version label is the
  recipe's but its files are the worktree's). Test: `VFIO_USER_SERVER=<libvfio-user>/build/samples/gpio-pci-idio-16
  OMARCHY_PATH=<omarchy worktree> bin/omarchy-iso-test <iso> --fake-pci 106b:1802:088000
  --no-preview` (~40 min; `--reuse-base --keep-running` then ssh `omarchy@127.0.0.1 -p 2222`
  with the run's `id_ed25519`). Expected VM-only failures: `t2-wifi-firmware` (no macOS volume)
  and `systemd-modules-load` (`t2bce_vhci` EPROBE_DEFER: a fake 106b:1802 has no BCE). Write a
  stick raw (`dd` + compare), never sparse.

## Facts that cost time to learn

- **KaiT2en's `6ddacd9` (2026-11-11, "apple_t2_bridge: initial implementation") replaces the
  whole t2bce stack**: every `modules/t2bce_*` (keyboard `t2bce_vhci`, audio `t2bce_audio`, …) and
  `modules/t2bce_audio-alsa-ucm-conf` are gone, replaced by `modules/apple-t2-bridge`
  (`snd_apple_t2`) and `modules/apple-t2-alsa-ucm-conf`. Re-pinning `t2bce-stack-dkms` or
  `t2bce-audio-ucm` at or past it would ship no keyboard driver: their `prepare()` stops the
  build there. Moving to it is a port by hand (new package, initramfs `MODULES` in `fix-t2.sh`,
  UCM, the DSP's udev match, the dotfiles' hid/audio assumptions), after the one-month rule.
  `kait2en-sync` took it for a repo-wide sweep (12 folders) until a commit that deletes or
  renames files in a package's paths stopped counting as one.

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

In order of value for the MacBookPro16,1. "Eligible" is the earliest date under the one-month
rule (30 days after the path's last real change as seen on 2026-11-12); any later change pushes
it back, so re-check with `git log -- <path>` before starting.

1. **ACPI fixes** (`scripts/fedora/acpi-autofix.py`, `install-acpi-fixes.sh`): eligible now
   (last real change 2026-10-07). An override for the CpuSSDT sub-table loading error and the
   DSDT `_OSC` buffer overflow; this Mac logs the first on every boot (`AE_ALREADY_EXISTS ...
   Aborting method \_PR.CPU0._OSC/_PDC`). KaiT2en ships it for dracut
   (`acpi_override`); here it would go through mkinitcpio's ACPI override in the UKI. A DSDT
   override is high-risk (a bad table can stop the boot): test from a snapshot with the Limine
   fallback entry at hand.
2. **`brcmfmac` Wi-Fi patches** (`patches/runtime/wireless`, `install-wireless.sh`,
   `install-kernel-args.sh`): eligible 2026-12-11. Same pattern as `t2-bluetooth-dkms`; one
   firmware timeout after a resume was seen. KaiT2en's kernel arguments now assume them
   (asynchronous suspend for the BCM4364).
3. **`16_1` speaker DSP profile** (`dsp/profiles/16_1`, `install-dsp.sh`): **done 2026-11-12, as an
   exception to the one-month rule** granted by the owner (would have been eligible 2026-12-08);
   sounds like macOS, ~17% of one core while playing, 0 xruns. Packaged as `t2-dsp` at `402a353` (2026-11-08), the last DSP before
   `6ddacd9`: its udev rule matches `KERNELS=="t2bce_audio"`, the driver in use; from `6ddacd9`
   on it matches `snd_apple_t2`. PipeWire filter chain; needs `lsp-plugins-lv2` (`[extra]`) and
   bankstown (`bankstown-lv2`, packaged here: AUR only). Userspace only: removing the package
   and rebooting undoes it.
4. **Packaging the firmware fetcher here**, to drop `[arch-mact2]` (`SigLevel = Never`): ours,
   no wait.
5. **dGPU power** (`modules/t2gmux`, `patches/runtime/gpu-runtime-pm`, `apps/t2-dgpu-control`,
   `apps/t2-hybrid-gpu-control`): eligible 2026-12-10. Two amdgpu patches are specific to the
   MacBookPro16,1; review the loadout's `t2-gmux-backlight` and `t2-render-gpu` with it, and the
   `amdgpu ... sdma0` fence warnings.
6. **Touch Bar** (`modules/t2touchbar`, `modules/t2bdrm`, `apps/t2-touchbar`): eligible
   2026-11-30. Replaces hid_apple: the loadout's `t2-hid-apple-keyboard` swaps move with it.
7. **Trackpad haptics** (`modules/t2_trackpad_actuator`, `apps/t2-force-click`): eligible
   2026-12-08.
8. **The rest, each with its own clock**: Thunderbolt runtime patches (`patches/runtime/
   thunderbolt`, 2026-12-11), `t2-services` (`t2-ave`, `t2-journal`; 2026-12-08; they use the T2
   bridge link, which the udev rule keeps NetworkManager off but leaves up), `t2-kbd-backlight`
   (2026-11-29), `t2-sidecar` (2026-11-23), AirShare/AirDrop (`t2-airshare`, `t2-drop`;
   2026-12-04), `t2-truetone` (2026-12-08), i915 PSR (`patches/runtime/i915`, 2026-12-08; the
   16,1's panel is on the dGPU, so low value), Touch ID (`modules/t2sep`, 2026-12-08; the Secure
   Enclave: wait longer than the minimum). Skip `t2-power-tune`/`t2-zone-power` until the dGPU
   work lands. New on 2026-11-11, not before 2026-12-11: `modules/apple-t2-bridge`,
   `modules/apple-t2-alsa-ucm-conf`.

Ours, no wait: make `t2-dkms-guard` warn when a kernel skips a package (the 7.3 Bluetooth gap),
and boot the live ISO on linux-omarchy instead of linux-t2.
