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
`t2smp-dkms`, `t2thunderbolt-dkms`, `t2-precision-trackpad-dkms`, `t2-trackpad-actuator-dkms`, `t2-force-click`, `t2-wireless-dkms`,
`t2-fan-control`, `t2-smc-control`, `t2bce-audio-ucm`, `t2-dsp` (with `bankstown-lv2`, not KaiT2en's),
`t2-dkms-guard`, `t2-touchid`, `t2-arch-packages-keyring`. Arch's own
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

**ISO rebuilt 2026-11-12** from `t2-kait2en-stable` (`omarchy-2026.11.12-x86_64-local-stable.iso`):
stable (`omarchy-settings`), every T2 package in the offline mirror (but `t2-dkms-guard` 0.1: 0.2
was published after the build fetched; the first `omarchy update` brings it), `fix-t2.sh` the
branch's. The build first failed: a freshly pulled `archlinux:latest` was ahead of the stable
snapshot (OpenSSL 4 against 3.6) and `pacman -Syu` couldn't settle; the omarchy-iso fork's
`builder/build-iso.sh` now runs `-Syuu` so the container also downgrades to the channel. **Fake-T2
test:** install, first boot and the system checks pass; the failed units are the two expected
(`systemd-modules-load`, `t2-wifi-firmware`); three on-screen checks fail, the same on a rerun
(`--reuse-base`): "style submenu is visible" (the menu lands on Trigger), "menu opens on
temporary monitor", "notification content is visible". The fork's diff to the stable commit
touches none of that, and the T2 services wait for hardware the VM lacks, but **no baseline yet**:
build a stock stable ISO from `a948d8a68` and run the same test to see whether upstream fails
them too (the harness is omarchy-iso's newer `quattro`, the tests are the 4.5.0 tree's).

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
  baseline, and the next re-pin follows it. Exception (2026-11-14, by the owner): `t2-fan-control`
  re-pinned to `8c7f725` (2026-11-12: in SMC mode, automatic control off, the daemon sleeps until
  the GUI asks instead of polling; no change with our config's automatic control on).
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
  `t2-wireless-dkms` (was `t2-bluetooth-dkms`) rebuilds btbcm/hci_uart/hci_bcm4377 and brcmfmac
  from kernel.org 7.2.15 with KaiT2en's patches 0001-0024; `BUILD_EXCLUSIVE_KERNEL="^7\.2\.…"`,
  so on 7.3 its sources move by hand: until then `t2-dkms-guard` (0.2) holds a 7.3 kernel back
  ("would be left out"; `T2_DKMS_GUARD_ALLOW_SKIP=1` lets it through without the module).
  linux-omarchy is kernel.org 7.2.15 (no stable-review patch) **plus patches of its own in some
  of the drivers we rebuild** (found 2026-11-16, omarchy-pkgs `pkgbuilds/linux-omarchy`): its
  Bluetooth ones touch only btusb/btintel*, but 0680/0681 touch brcmfmac, ~15 touch amdgpu,
  ~11 i915, and 0601-0608 Thunderbolt (those change `include/linux/thunderbolt.h`, so a plain
  7.2.15 thunderbolt doesn't build). `t2-thunderbolt-dkms` applies Omarchy's first;
  `t2-wireless-dkms`, `t2-amdgpu-dkms` and `t2-i915-dkms` still build plain 7.2.15 and so drop
  Omarchy's fixes in those drivers (they build and work; to fix). DKMS 3.4 skips a module whose srcversion matches
  the in-tree one ("already installed (unversioned module)"): the patches leave `brcmutil` and
  `brcmfmac-wcc/-cyw/-bca` the same code (checked by disassembly), so the stock ones stay, and
  `dkms status` reports "Differences between built and installed modules". Harmless.
- **`hid-apple` binds every interface of the T2 trackpad/keyboard device** (it matches by ID),
  the Taptic Engine's included, and the HID core rehands only interfaces bound to hid-generic:
  `t2_trackpad_actuator` loaded later gets nothing (KaiT2en's own `t2hid` keeps hid-apple off
  them). `t2_precision_trackpad` gets its interface by loading first in the initramfs; the
  actuator's package ships a udev rule instead: on `ACTION=="add|bind"` with `DRIVER=="apple"`
  for the T2 trackpad IDs, a helper moves the interface whose report descriptor starts
  `06 00 ff 09 0d` (usage page 0xff00, usage 0x0d) and gives it back to hid-apple if binding
  fails. `add` is the one that catches it at boot: hid-apple binds these in the initramfs, whose
  udev only carries mkinitcpio's four rule files, and the real root's coldplug replays them as
  `add` events (driver already bound); after a resume the T2 bus enumerates them again and the
  `bind` does. A rule on `bind` alone passes a manual rebind test and fails at every boot.
- `fix-t2.sh` must not contain the word `brcmfmac` (not even in a comment):
  `test/shell.d/brcmfmac-supplicant-test.sh` keeps that driver's modprobe file to one owner.
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
- On linux-omarchy, t2smc is rtc1 (the ACPI TAD moved to rtc2). t2smc writes the system time to
  the EC clock itself in its suspend and shutdown callbacks (as macOS does before every power
  transition; the kernel's NTP writeback stops at rtc0), so the dotfiles' `t2-boot-clock`
  shutdown unit was retired on 2026-11-12.
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

1. **ACPI fixes** (`scripts/fedora/acpi-autofix.py`): **done 2026-11-15 as `t2-acpi-fix`**, the
   owner's choice although the gain is mostly correctness (eligible: last change eebd9b1,
   2026-10-07). Every boot logged 18 `AE_ALREADY_EXISTS` lines: the `CpuSsdt`'s `GCAP` re-loads
   sub-tables the kernel already loaded, aborting `\_PR.CPU0._OSC`, CPU1's `APPT`/`APCT` and
   CPU0-2's `_PDC`. The override sets `Name (\SDTL, Zero)` to the mask of those sub-tables
   (`0x3A` here: CPU0IST, CPU0CST, APIST, APCST) and bumps the revision (`0x3001`; the kernel
   only upgrades to a higher one). After it: no ACPI errors, `_OSC`/`_PDC` complete on every
   CPU, and the firmware also loads `Cpu0Psd` (never loaded before). No measurable change:
   `intel_pstate` with HWP (no `_PSS`/`_PSD` use), turbo to 5.0 GHz, `intel_idle`'s own table, C10
   as before; deep sleep and wake fine. The DSDT `_OSC` buffer overflow the script also fixes
   doesn't happen on this Mac.
   - **How it lands**: `sudo t2-acpi-fix` (machine-specific: built from the running Mac's tables
     and this boot's log; `--build-only` shows the result first) writes
     `/etc/initcpio/acpi_override/161CpuSSDT.aml` and `/etc/mkinitcpio.conf.d/zz-t2-acpi-fix.conf`
     (`HOOKS+=(acpi_override)`, after `00-omarchy-hooks.conf`, which resets HOOKS; mkinitcpio's
     hook fails the build with no `.aml`), then `limine-mkinitcpio` and a reboot. Proof it's
     active: `ACPI table found in initrd [kernel/firmware/acpi/161CpuSSDT.aml]` and
     `Table Upgrade: override [SSDT-CpuRef- CpuSsdt]` in the kernel log. Undo: remove both files,
     rebuild, reboot (or boot a snapshot from Limine). Rerun after a firmware update.
   - **Fresh installs** (the fork's `fix-t2.sh`, `0f2f6aca8`): it installs the package and a
     one-shot `t2-acpi-fix.service` that runs on the first boot, after journald and before the
     login screen (`Before=display-manager.service`): `t2-acpi-fix`, then `limine-mkinitcpio` if
     the drop-in exists, then `/var/lib/t2-acpi-fix/done` (its `ConditionPathExists=!`, so it
     runs once; a failure retries next boot). The fix applies from the second boot. Tested on
     this Mac (2026-11-15) by removing the override and rebooting: the unit built the same
     table and the image before the login (+14 s, that boot only), and the next boot loaded it
     with no ACPI errors and skipped the unit. Not in an ISO yet.
2. **`brcmfmac` Wi-Fi patches** (`patches/runtime/wireless`): **done 2026-11-12, as an exception to
   the one-month rule**, at the existing pin `27fd5c9` (patches 0001-0024): `t2-bluetooth-dkms`
   became `t2-wireless-dkms`. **Re-pinned 2026-11-16 to `7e9903c`** (0001-0027, the owner's
   exception): 0025 (BCM4364 rev 3 antenna SKU, iMacs) and 0026 (BCM4377 ASPM, PCIe Bluetooth)
   don't touch this Mac; 0027 (brcmfmac inband deep sleep) only switches on when the firmware
   sets shared flag 0x40000000, and this Mac's (9.30.514.0.32.5.94, from macOS) doesn't: with
   `brcmfmac debug=0x80000` and dynamic debug on, no "deep sleep" messages in 20 s idle, and
   `pmc_core/ltr_show` `SOUTHPORT_A` still 61 us. Wi-Fi, Bluetooth LE devices, S3 and AirDrop
   fine; first ping after idle unchanged (~2 ms).
3. **`16_1` speaker DSP profile** (`dsp/profiles/16_1`, `install-dsp.sh`): **done 2026-11-12, as an
   exception to the one-month rule** granted by the owner (would have been eligible 2026-12-08);
   sounds like macOS, ~17% of one core while playing, 0 xruns. Packaged as `t2-dsp` at `402a353` (2026-11-08), the last DSP before
   `6ddacd9`: its udev rule matches `KERNELS=="t2bce_audio"`, the driver in use; from `6ddacd9`
   on it matches `snd_apple_t2`. PipeWire filter chain; needs `lsp-plugins-lv2` (`[extra]`) and
   bankstown (`bankstown-lv2`, packaged here: AUR only). Userspace only: removing the package
   and rebooting undoes it.
4. **Packaging the firmware fetcher here**, to drop `[arch-mact2]` (`SigLevel = Never`): **done
   2026-11-15.** `apple-bcm-firmware-fetcher` 1-2 is arch-mact2's 1-1 (NoaHimesaka1873/
   arch-mact2-PKGBUILDs at 019d2f25) with only the optdepends changed: same name, script,
   scriptlet and state path, so the upgrade runs neither `pre_remove` (which deletes every
   firmware file it listed; the ~148 `brcm/*apple*` files are unowned) nor `post_install`. A new
   name with `replaces` would have removed the old package and the firmware with it. The fork's
   `install/hardware/pacman.sh` no longer adds `[arch-mact2]`; the ISO builder still uses it at
   build time (the live ISO's `linux-t2`), and its `ship-sync-databases.sh` stops shipping
   `arch-mact2.db` since the fork no longer names it.
5. **dGPU power, hybrid graphics** (`modules/t2gmux`, `patches/runtime/gpu-runtime-pm`,
   `apps/t2-hybrid-gpu-control`): first deferred to linux-omarchy 7.3 (2026-11-12), then **done on
   7.2.15 after all** (the owner, 2026-11-15: Omarchy's 7.3 move, omarchy-pkgs#1421, has sat as a
   draft since 2026-10-21). **Stage 1 done 2026-11-15**: `t2gmux-dkms` (0.9, at `c9e24f7`) and
   `t2-amdgpu-dkms` (7.2.15's amdgpu with a series vendored in the package: 0002 from the 7.3
   rebase `3fc53bf`, which applies to 7.2.15 cleanly, and 0004-0009, 0011, 0012 from `a9a42a7`,
   0012's include context fixed; no fuzz, checked in `prepare()`). Booting on the dGPU as before:
   `t2gmux: Found gmux version 5.0.0 [T2]`, `amdgpu: Using Apple GMUX for runtime pm`,
   `vga_switcheroo: enabled`, the dGPU's `power/control` now `auto` (`active`: it drives the
   panel), `gmux_backlight` kept (t2-truetone drives it), deep sleep and wake fine (0008 logs the
   VBIOS-trained UCLK levels on resume). `apple_gmux` is skipped by `t2gmux-dkms`' modprobe
   `install` line where t2gmux exists, and a `softdep amdgpu pre: t2gmux` loads it first (in the
   initramfs too). DKMS builds amdgpu in about 5-9 min (988 objects, a ~3 GB build tree, 8.9 MB
   installed), on every kernel update; the package carries only `drivers/gpu/drm/amd` (536 MB in
   /usr/src). `Fence fallback timer expired on ring sdma0` twice at boot, as on 2026-11-12 with the
   stock driver: watch. `t2gmux-dkms` 2 carried an ordering patch of ours (gmux as a
   device-link supplier of the iGPU, so it resumes first): correct but no help with the black
   panel, dropped in 3.
   **Stage 2 done 2026-11-16**: the boot GPU on the iGPU (`t2-boot-gpu integrated`), with
   `t2-i915-dkms` (7.2.15's i915 + drm_display_helper, KaiT2en's 0001-0003, and our 0004).
   Hyprland on `card1` (i915; the dotfiles' `t2-render-gpu` follows the panel), the dGPU in
   D3cold (`runtime_status` suspended) and woken for `DRI_PRIME=1` (Chromium) and back, the
   gmux brightness restored after a lock (0003), suspend fine. Battery draw idle: 32 W on the
   dGPU (2026-11-12) -> about 13 W hybrid (screen ~15 %).
   - **The panel after S3 in hybrid mode** stayed dark (backlight on) until the next modeset:
     it comes out of S3 not answering AUX ("Set power to D0 failed", "Sink disconnected:
     Failed to enable link training" at drm debug level, then hundreds of AUX timeouts for as
     long as one waits). Not the mux order, not PSR, not the panel power up delay (the firmware
     leaves 12.5 ms, `PP_ON 0x7d0001`, and there's no VBT; 210 ms made no difference). Only a
     modeset that power cycles the panel brings it back, so **0004** forces a retrain 500 ms
     after a failed training, up to 3 times, without lowering the link rate, on the Macs of
     0003's DMI list (`Applying gmux eDP resume retrain quirk`). Wakes now show the lock screen
     by themselves (Omarchy's lock still blanks ~5 s after a wake, as on the dGPU).
   - **No Apple PSR on these Macs** (0004 again): with PSR on, `intel_dp_needs_link_retrain()`
     skips the link, so the retrain never happens, and i915 marks the sink "not reliable" at
     the first wake anyway (two `PSR aux error` at resume). PSR off caps the package around
     PC8.
   - **`t2-boot-gpu`** (ours): `t2-boot-gpu [integrated|discrete|apply]` writes Apple's
     `gpu-power-prefs` (`07 00 00 00 01 00 00 00` iGPU, `… 00 …` dGPU; immutable, chattr'd) and
     keeps the choice in `/etc/t2-boot-gpu.conf`; `t2-boot-gpu.service` re-applies it at boot and
     shutdown, so after a macOS boot (which writes the dGPU) the first Linux boot is on the dGPU
     and the next is hybrid. External displays on the Thunderbolt ports need `discrete`. The
     dotfiles' `t2-hybrid-boot` sets `integrated` and enables the service. Not in the fork yet.
   - **Idle power, what's left** (2026-11-16, on battery, hybrid): the package never goes below
     PC3 (PC2 ~20 %, PC3 ~52 %, PC6-PC10 0; PkgWatt ~2.7 W of the ~13 W). No change from
     runtime PM `auto` on every PCI device but the T2's, ASPM L1 on the Wi-Fi link, or ignoring
     the Wi-Fi's LTR (`SOUTHPORT_A` 61 us in `pmc_core/ltr_show`; KaiT2en's 0027 targets it).
     ACPI's FADT disables ASPM ("doesn't support PCIe ASPM"). KaiT2en's own 15,1 baseline is PC3
     too ("Thunderbolterella", 2026-08-15): the deep states come back only with Thunderbolt
     killed (which doesn't come back); their Titan Ridge runtime-PM work
     (`patches/currently-testing/titan-ridge-runtime-pm`, needs `pcie_ports=compat` gone) is the
     next lead, with its resume-time cost to measure.
   - **Never runtime-PM the dGPU's PCIe path**: root port `00:01.0` and bridges `01:00.0`/`02:00.0`
     must stay `power/control=on` (the default; t2gmux handles the dGPU's own D3cold). The
     2026-11-16 power test set every PCI device but the T2's to `auto`: from then on every dGPU
     wake failed ("Unable to change power state from D3cold to D0, device inaccessible", SMU and
     atombios errors), a `lspci` hung on it, and the next `reboot` hung on a black screen (forced
     power-off, which also relocks Touch ID). A reboot clears it. KaiT2en's `t2-power-tune` sets
     `auto` broadly: exclude this path if it's ever ported.
   - **The fork** (`ebbfbf798`) installs the four packages on dual-GPU Macs (found by PCI class in
     sysfs, which doesn't wake the dGPU) and leaves the boot GPU alone; the dotfiles'
     `t2-hybrid-boot` switches to hybrid. Not in an ISO yet.
   - **Why it matters:** the panel (eDP) is wired to the AMD dGPU at boot, so it never sleeps
     (`power/control` = `on`, D0): **32 W on battery** measured 2026-11-12 (~1.8 h). In hybrid mode
     the Intel iGPU drives the panel and Hyprland, and the dGPU sits in D3cold until an app asks
     for it (`DRI_PRIME=1`), through PRIME offload.
   - **What it takes:** (1) `t2gmux` (DKMS, has a `dkms.conf`) in place of `apple_gmux`: blacklist
     `apple_gmux` and load `t2gmux` early in the initramfs (`MODULES` in `fix-t2.sh`): "GMUX must
     provide the power callbacks before AMDGPU probes". It keeps the `gmux_backlight` name and has
     `boot_gpu` (-1 auto, 0 iGPU, 1 dGPU). (2) `amdgpu` rebuilt from kernel sources with the series,
     like `t2-wireless-dkms` (`drivers/gpu/drm/amd`: 536 MB, ~1000 .c files: measure the DKMS and
     `t2-dkms-guard` build time; `amdxcp` and other side modules may be code-identical, as with
     brcmfmac's helpers). 0001 (VI reset) is in the kernel since 7.2.10: skip it. 0008, 0009 and
     0012 are MacBookPro16,1-specific. (3) The boot GPU set to the iGPU: the Apple EFI variable
     `gpu-power-prefs-fa4ce28d-b62f-4c99-9cc3-6815686e30f9`, `07 00 00 00 01 00 00 00` for the
     iGPU (`... 00 ...` for the dGPU; efivarfs files may need `chattr -i`). **macOS resets it to
     the dGPU at every macOS boot**: KaiT2en's answer is `t2-gpu-preboot`, a UEFI program made the
     first boot entry; the plan here was a loadout script plus a boot unit that set it back
     instead (the first Omarchy boot after macOS then runs on the dGPU, the next is hybrid), no
     UEFI binary in the boot chain. The dGPU's `power/control` must read `auto`.
   - **Found on 7.2.15 at the pin `27fd5c9`:** 0002 (the GMUX runtime-PM patch) and 0012 don't
     apply cleanly (written against other sources: offsets up to 290 lines). The rejects were
     trivial (a `bool gmux, px;` declaration in `amdgpu_device_fini_sw`, an
     `#include <linux/dmi.h>` in `amdgpu_dm.c`), but several hunks went in with fuzz and would
     each need checking by hand. On 7.3 with KaiT2en's rebased series that should be moot: check
     with `patch --dry-run` first.
   - **The HDA patch** the app's README mentions ("allow direct-complete with a powered-off GPU")
     isn't in KaiT2en's runtime set (only `currently-testing/` and `upstream/submitted/`), and its
     installer removes the patched `snd-hda-intel` it used to ship.
   - **The dotfiles:** `t2-render-gpu` picks the card whose eDP is connected at each login, so it
     follows the panel to the iGPU by itself (and so keeps Hyprland off the dGPU).
     `t2-gmux-backlight`'s udev rule matches `gmux_backlight`, which `t2gmux` keeps: verify.
     **External monitors** on the Thunderbolt ports hang off the dGPU: in hybrid mode, with
     Hyprland on the iGPU only, they need a dGPU boot.
   - **Plan, in two stages:** stage 1, `t2gmux` and the patched `amdgpu` installed while still
     booting on the dGPU (nothing visible changes: proves the drivers, backlight, suspend, build
     time); stage 2, the boot GPU flipped to the iGPU: check the panel on Intel, the dGPU in
     D3cold, battery draw, suspend, brightness, a `DRI_PRIME=1` app. Ways back: the variable back
     to the dGPU, or one macOS boot; removing the packages; the Limine fallback.
   - **Fans, after stage 2** (owner, 2026-11-14): with idle draw down, compare `t2-fan-control`'s
     SMC mode (automatic control off; since `8c7f725` the daemon sleeps then) against automatic
     with the 80 °C target: idle draw with each, then 10 min of load (temperatures, rpm,
     throttling). Switch only if the SMC's curve keeps it cool enough; on Linux it ramps late.
   - KaiT2en's i915 patches (`patches/runtime/i915`: PSR on Apple panels, restoring the gmux
     brightness) matter once the iGPU drives the panel: look at them with this.
6. **Touch Bar** (`modules/t2touchbar`, `modules/t2bdrm`, `apps/t2-touchbar`): **done 2026-11-14, as an
   exception to the one-month rule** (pin `c9e24f7`; module code unchanged since 2026-10-28, the
   app since 2026-10-31). `t2-touchbar-dkms` (`t2hid`, `t2touchbar_kbd`/`_bl`, `t2bdrm`) and
   `t2-touchbar` (the daemon). Tested on this Mac: live swap, then the bar, touch, swipes, layers,
   haptics, the Touch ID prompt, suspend, and a reboot with `t2hid` at the unlock prompt.
   - **They don't need `apple-t2-bridge`**: plain HID/USB/DRM drivers matched by device ID, no BCE
     symbols or headers (6ddacd9 changed only a README line there). Built on 7.2.15 cleanly.
   - **Installed inert**: `t2hid`/`t2touchbar_*` claim the same IDs as `hid-apple` and
     `hid-appletb-*`, and udev would load both at every boot and resume. The package's
     `/usr/lib/modprobe.d/t2-touchbar.conf` blacklists ours; the switch-over is
     `/etc/modprobe.d/t2-touchbar.conf` (same name, so it takes that file's place) blacklisting
     `hid_apple`, `hid_appletb_kbd`, `hid_appletb_bl`, `appletbdrm`, plus `t2hid` in
     `apple-t2.conf`'s `MODULES` in `hid_apple`'s place (a blacklist doesn't stop a module named
     there; modconf carries the blacklist into the image for the `keyboard` hook's autoload). The
     fork's `fix-t2.sh` writes both; the dotfiles' `t2-touchbar-switch` writes them with the
     keyboard options (`options t2hid …`, the same as hid-apple's) and replaced
     `t2-hid-apple-keyboard`.
   - **The daemon** (`t2-touchbar`, renamed from `kait2en-touchbar`, as are its units, udev rule,
     group, `/etc/t2-touchbar`, `~/.config/t2-touchbar`, `T2_TOUCHBAR_*`): a root
     `t2-touchbar-attach.service` (udev-wanted on 05ac:8302 in configuration 1, only while the user
     unit is enabled globally) switches the bar to configuration 2, where `t2bdrm` makes a DRM card
     on a private seat (`seat-touchbar`; Hyprland ignores it); the user service draws on it. Group
     `t2-touchbar` (sysusers) opens that card, the digitizer, the keyboard's event node (Fn),
     `/dev/uinput`, the bar's light and the actuator's `play`. A new group reaches the user
     session only after a reboot: the user's systemd manager keeps its groups across logins while
     anything else runs. Fonts patched to Arch's (`adwaita-fonts`). The Touch ID D-Bus name is
     `io.github.josemiguelo.T2TouchId` on both sides (`t2-touchid` 3).
   - **Live testing** (how it was proven): `modprobe -r hid_apple && modprobe t2hid <options>` with a
     `systemd-run --on-active=` revert armed; then `t2touchbar_kbd`, `t2bdrm`, the global enable,
     `systemctl start t2-touchbar-attach`, the user service. A revert has to stop the user service
     first (`systemctl --user -M <user>@ stop t2-touchbar`), or `t2bdrm` stays in use. A package
     installed on a running system sets the actuator's `play` group only at the next udev event,
     so restart the app once (at boot the rule runs first).
   - **Ways back**: delete `/etc/modprobe.d/t2-touchbar.conf`, `hid_apple` back in `apple-t2.conf`,
     `limine-mkinitcpio`; at the unlock prompt, a USB keyboard (hid-generic) or a pre-change
     snapshot. `t2-touchbar --detach` (or disabling the unit globally) brings Apple's firmware row
     back.
7. **Trackpad haptics** (`modules/t2_trackpad_actuator`, `apps/t2-force-click`): **done
   2026-11-12, as an exception to the one-month rule**: `t2-trackpad-actuator-dkms` (with a udev
   rule, see the facts above) and `t2-force-click`. The force click replays Apple's captured
   plain click, so it feels like a second click, not macOS's force-click haptic.
8. **Thunderbolt hotplug and controller power-down** (`patches/runtime/thunderbolt`): **stage A
   done 2026-11-16** (the owner's exception to the one-month rule) as `t2-thunderbolt-dkms`
   (7.2.15 `drivers/thunderbolt` + Omarchy's 0601/0602/0605/0606/0608, vendored from omarchy-pkgs
   `48d5518`, + KaiT2en's 0001 at `4b29a99` rebased onto them: one include hunk), replacing
   `t2thunderbolt-dkms`, **with `pcie_ports=compat` kept**: the patch's `thunderbolt-apple-power`
   binds the Titan Ridge root ports 00:01.1/00:01.2 itself ("Thunderbolt runtime power control
   enabled"), and 15 s after boot "Thunderbolt controller powered off": NHIs 08:00.0/7e:00.0 in
   D3cold, ports D3hot; the dGPU's 00:01.0 untouched. Package C-states on battery, idle, hybrid:
   PC2 ~48 %, PC3 ~2 %, **PC6 ~3 %, PC7 ~14 %** (before: PC3 at most), PC8+ 0 (no PSR);
   PkgWatt ~2.7 W as before, battery ~12 W (screen 9 %; before ~12.4-13 W at 15 %). Suspend fine
   (wake a little over 1 s), USB-C sticks on every port (the controller powers on for them),
   charging fine. Not tested: PCIe tunnelling (docks, eGPUs) and hotplug, which still need the
   port services `compat` turns off. Next (stage C): `pcie_aspm=force` for more PC7, separately
   (KaiT2en once turned forced ASPM off for this Navi).
   - The 16,1 has two Titan Ridge 4C controllers (`8086:15ea` bridges, `15eb` NHI, `15ec` xHCI).
     `pcie_ports=compat` (half of the ~16 s to ~1 s wake) turns the PCIe port services off,
     `pciehp` included: PCIe devices behind Thunderbolt (docks' NICs/NVMe, eGPUs) only appear if
     connected at boot; plain USB-C and displays are fine. No RTD3 either (KaiT2en measured PC10
     going from 33 to 64 % on a MacBookAir9,1; not measured on the 16,1).
   - **None of it is in the pin `27fd5c9`:** KaiT2en added the patched `thunderbolt` driver (RTD3
     for Titan Ridge and Ice Lake on T2 Macs) on 2026-11-10, dropped `pcie_ports=compat` for every
     Mac with it ("the Thunderbolt runtime PM needs the PCIe port services"), fixed it twice on
     2026-11-11 (one: keeping `pciehp`'s MSI), and retired `t2thunderbolt` (gone from its module
     list; the patched driver replaces it). At the pin it still added `pcie_ports=compat` on all
     Macs, as `fix-t2.sh` does.
   - **A port means:** `t2-thunderbolt-dkms` (kernel.org `drivers/thunderbolt` + the patch, like
     `t2-wireless-dkms`) replacing `t2thunderbolt-dkms`; `pcie_ports=compat` dropped from
     `fix-t2.sh`, the dotfiles' `t2-kernel-args` (which enforces it today) and Limine; the resume
     time re-measured; hotplug tested with a Thunderbolt dock or eGPU.
9. **Touch ID** (`t2-services/t2-touchid`): **packaged 2026-11-14 as `t2-touchid`, an exception to
   the one-month rule** (pin `c9e24f7`). Tested on this Mac by hand first: sudo, polkit and the lock
   screen, before and after suspend. How it works: the T2's Secure Enclave matches the finger
   (fingers enrolled in macOS only; it reports none until macOS has been logged into once since
   the T2 last lost power: seen 2026-11-16 after a forced power-off, "no macOS user on this Mac
   has a finger enrolled, or the SEP is still locked", every boot and wake until a macOS login;
   since pkgrel 4 a notification says so, `t2-touchid-notify`, once per locked spell); the daemon reaches its BiometricKit over BridgeXPC on the T2 link
   (`enp4s0f1u1`, the T2 at `fe80::aede:48ff:fe33:4455`, discovery port 59602) and hands verdicts to
   stock fprintd through libfprint's virtual storage driver (`FP_VIRTUAL_DEVICE_STORAGE`), which
   Omarchy's `libfprint-git` builds (`-D drivers=all`). With `--bind-user` it binds the macOS
   fingers to a Linux account without a touch: any finger enrolled in macOS unlocks it. A wrong
   finger gets a retry, not a no-match (upstream's choice: a bad read doesn't spend a PAM try), so
   sudo waits out `pam_fprintd`'s 30 s or Esc, then the password.
   - **The T2 link** must come up as the device appears (the package's udev rule, like KaiT2en's
     on `ACTION=="add"`): the T2 signals carrier once, when its NCM function is set up (bind,
     reset-resume), so a link opened later stays NO-CARRIER (found 2026-11-14: our
     `90-t2-ibridge-unmanaged` rule had only kept NetworkManager off it since 2026-11-12; a
     `cdc_ncm` unbind/bind of `7-1:1.0`, then `up`, gave carrier). It kept carrier across suspend.
   - **`resume-reopen.patch`** (ours): Omarchy locks just before suspend, so the lock's verify was
     waiting in the daemon; after resume it died on the dead session and the daemon sent fprintd
     `ERROR`, which failed the lock's next verify, and the lock stopped listening until a click.
     Now an attempt cut by a resume reopens the session and serves the standing prompt. KaiT2en's
     `t2-services-suspend.service` does nothing for Touch ID (its README: the daemon's logind
     watcher handles it); Omarchy's `fprintd-resume` hook (restarts fprintd) is fine with it.
   - **Omarchy's fingerprint setup and removal drive it** (pkgrel 2, 2026-11-14): the package ships
     `/usr/share/omarchy-platform/fingerprint-readers` (`/run/t2-touchid/reader ready`), Omarchy's
     hook for readers that aren't USB, and `reader-status.patch` has the daemon write that file
     (`ready` once the sensor answers and macOS has fingers, else `starting`/`unreachable`/
     `no-fingers`; world-readable, the runtime folder `0711`). So `omarchy-hw-fingerprint` finds it,
     and the menu's setup installs `libfprint-git` + fprintd, enrolls (fprintd's duplicate check
     then the enroll: about two touches; the daemon answers both with the macOS finger, which binds
     it), verifies and adds its PAM (sudo, polkit-1 behind its lid gate, `omarchy-apply-lock`). Its
     removal deletes the prints and PAM and drops fprintd and `libfprint-git`: hence those are
     `optdepends`, not `depends` (a dependency made its `pacman -Rns` fail). The daemon must be
     running for detection (no lifecycle hook: `omarchy-lifecycle-dispatch` registers none for
     x86), so the fork's `fix-t2.sh` enables it. Automatic binding (`T2_TOUCHID_BIND_USER`) stays
     `none`: it re-binds at every daemon start and would undo a removal. Tested end to end:
     remove, then setup from the menu. The libfprint-git `aurora-apple-sep.patch` in omarchy-pkgs is
     Apple Silicon's Touch ID (`/dev/sep-bio`), not this.
   - **Names**: unit, config and drop-in are neutral (`t2-touchid.*`, KaiT2en's trademark); the
     D-Bus name `org.kait2en.TouchId` is in the code, for the Touch Bar's animation: rename it with
     the Touch Bar port. sudo's prompt says "Swipe": the virtual driver's scan type, cosmetic.
   - **`[arch-mact2]` has a `t2-touchid` too** (gone with that repo, 2026-11-15) (KaiT2en's names, a network-setup service and a
     NetworkManager connection; version `0.1.0.r949…`, above ours). Ours wins because
     `[t2-arch-packages]` comes first in `pacman.conf` (`-S` and `-Syu` take the first repo that has
     it), but an install right after a publish got theirs (the CDN served the old database):
     replace it with `pacman -S t2-arch-packages/t2-touchid`. `epoch=1` would make ours outrank it
     everywhere, if it bites again.
   - **Not done**: an ISO with it (the fork installs and enables `t2-touchid`; `libfprint-git`
     and fprintd are in its offline list for the setup).
10. **Keyboard backlight idle fade** (`apps/t2-kbd-backlight`): **done 2026-11-15, as an exception to
   the one-month rule** (pin `c9e24f7`; one real commit, fb187c0). Not auto-brightness: it fades the
   keyboard backlight out after 30 s without keyboard, trackpad or Touch Bar input and back on the
   next, and sets the level back before suspend. A root system service, through UPower's
   `KbdBacklight` (never sysfs), its own libinput contexts on `seat0` and `seat-touchbar`. Config
   `/etc/t2-kbd-backlight/kbd-backlight.toml` (renamed). The ambient light sensor drives the
   screen instead, through `t2-truetone` (item 12).
   - **UPower missed Omarchy's keys**: `omarchy-brightness-keyboard` writes the LED with
     brightnessctl, and t2hid's LED has no `brightness_hw_changed`, so UPower's level went stale
     and it signalled nothing (the fade restored old levels; the Touch Bar's glyphs, which match the
     keys' level on UPower's signal, lagged). The dotfiles' `t2-kbd-backlight-sync` wraps the
     command to call `KbdBacklight.SetBrightness` with the LED's level after it. `t2-touchbar` 2
     fixed a leftover `/etc/kait2en` path in its config comment (its name check now covers
     `config/`).
11. **AirDrop and Quick Share** (`apps/t2-drop`, `apps/t2-airshare`): **packaged 2026-11-15, as an
   exception to the one-month rule** (pin `c9e24f7`). AirDrop tested both ways with an iPhone,
   Quick Share both ways with a Galaxy A56 over the shared Wi-Fi (2026-11-15). The hotspot path
   is untested, by the owner's choice (phone Wi-Fi stays on): with the phone's Wi-Fi *off* the
   Mac isn't listed at all, which is expected (it couldn't join the hotspot); a btmon capture
   showed the Mac's FEF3 advertisements on air and the phone's FE2C beacons, no connection. The
   test needs the phone's Wi-Fi on and off any network. The fork's `fix-t2.sh` installs both and adds the ufw rules (same
   comments as the dotfiles' check); the receiver stays off until the owner turns it on.
   - **Omarchy integration** (dotfiles, not packaged): a bar widget and panel,
     `josemiguelo.airshare` (visibility switch, send files / clipboard / last screenshot through
     AirShare's send window, received files from the receiver's journal, trusted devices), and
     Share-menu entries beside LocalSend's (`t2-airshare-menu`). A native device list, progress and
     inline accept need AirShare to expose them (a `list --json`, `send --json`, receive events).
   - **Driver side already shipped**: everything both need is in `t2-wireless-dkms`' 0001-0024
     (0005 AP handshake to the host, 0006-0011 AWDL, 0012-0013 LE scan, 0014 ND offload). This Mac
     (BCM4364/4 b3, FWID 01-68d7ff80, untested upstream) keeps its 5 GHz station link while AWDL
     runs (checked: channel 48, no firmware errors).
   - **`t2-drop` 3 carries two patches of ours**: `discovery.patch` (the AirDrop port from the AirDrop
     instance's SRV record, not the last SRV in a peer's frame, which was an iPhone's ephemeral
     port; with a fallback to the last SRV when the name is only a compression pointer; and a
     session's discovery threads stop with it), `connect.patch` (4 TCP connect attempts of 3 s:
     over AWDL beside the station link the first SYNs get lost, and a send failed on one).
     `!lto`: makepkg's `-flto` turns `ring`'s C objects into bytecode rust-lld can't link.
   - **`t2-airshare` 2**: `omarchy.patch` fixes the Quick Share port at 47901 (upstream: any free
     port, which ufw can't allow), removes the KaiT2en wordmark, and skips the AppleDouble `._name`
     files iPhones send beside each file. The hotspot helper opens its port only with firewalld;
     the dotfiles' `t2-airshare-firewall` adds ufw rules (47901/tcp, `in on t2qs0`, 8770/tcp
     `in on awdl0`). The receiver is a user service the app's "visible" switch runs (it makes the
     Mac Bluetooth-discoverable); "Always trust" matches by device name only.
   - **Seen in testing**: `t2drop list` waits 15 s and a later session's first discovery can take
     ~15 s (the first connect lands before awdl0's address is usable), so use `--wait 30`; the app
     browses while its window has focus. An iPhone may send a transfer twice (each upload ends
     with a connection reset): watch.
12. **True Tone and auto-brightness** (`apps/t2-truetone`): **ported 2026-11-15, as an exception to
   the one-month rule** (pin `c9e24f7`; 8de9546, 2026-11-08, then only a lockfile sweep). Upstream
   is GNOME-only; `omarchy.patch` (ours, about 400 lines in, 1400 out with the GTK app) swaps the
   backends and keeps the core (sensor, white-point model, macOS curve, ramps, learning, config,
   status file) as it is. Tested on MacBookPro16,1: the panel warms with the room (~6400 K at
   68 lux, strength 0.2) and stacks on Omarchy's night light; brightness follows the curve, dims
   slowly and brightens fast, and learns a manual level a second after the keys stop.
   - **The sensor**: USB HID `05ac:8262` behind the T2, `hidraw` (lux, CCT, chromaticity by
     `HIDIOCGINPUT` report 1) and also `iio:device0` (`hid_sensor_als`; its raw value is milli-lux
     though `in_illuminance_scale` says 1). The package's udev rule tags the hidraw node `uaccess`.
   - **Colour**: a gamma table through `wlr-gamma-control` (Hyprland 0.56 gives eDP-1 a 4096-entry
     table); the compositor drops it when the daemon exits. hyprsunset (night light) uses the CTM,
     so both apply; a second `hyprland-ctm-control` client would have broken night light. No base
     table to read back, so the base is the identity.
   - **Brightness**: logind `Session.SetBrightness` on the first firmware/platform/raw backlight
     that isn't the Touch Bar's (`gmux_backlight`; `T2_TRUETONE_BACKLIGHT` overrides), floor 1 %.
     No signal for a manual change under Omarchy, so a sysfs level it didn't write is one; changes
     in its first 5 s are followed, not learned (the dotfiles' login listener restoring a level).
     The dotfiles' gmux resends after wake and screen-on write the kernel's own value back, so
     they don't count as manual.
   - **Omarchy side** (dotfiles): the user service enabled (`t2-truetone-daemon`) and a bar widget,
     "Ambient Light" (`josemiguelo.truetone`): the service switch, True Tone with its strength,
     automatic brightness, the live reading, forgetting the learned curve. Its evening mode is
     left off (night light does it). The fork's `fix-t2.sh` installs it and enables the user
     service globally (`aaa3b48d9`); not in an ISO yet.
13. **`t2-services`**: **done 2026-11-16** (the owner's exception to the one-month rule), both over
   the T2 link `t2-touchid`'s udev rule brings up (upstream's `t2-services-common` does the same
   and is otherwise Fedora migration scripts: not packaged).
   - **`t2-journal`** (at `c9e24f7`): `t2journal`, run as the user, pulls a bridgeOS sysdiagnose
     over BridgeXPC and merges the T2's unified logs with a Linux boot (`t2journal -b --grep
     'suspend|smc'`, `--list-boots`, `refresh [--sysdiagnose]`; snapshot in
     `~/.local/state/t2-journal`, ~41 MB, ~30 s to refresh). Tested; Touch ID unaffected.
   - **`t2-ave`** (at `27fd5c9`, the `t2bce-stack-dkms` pin, so `t2remote` matches the installed
     `t2bce_ave`/`t2bce_sidecar`; upstream later renames them `t2-ave`/`t2-sidecar` on
     `apple-t2-bridge`): `t2-ave.service` (ours, for `kait2en-t2-remote.service`) loads the modules
     and runs `t2remote daemon` (root, `/run/t2remote.sock` root-only), which holds
     `com.apple.aveservice` and `…videoprocessingd.encode.remote`; the T2 then shows the Sidecar
     encoder as USB `05ac:9312`. V4L2 mem2mem: "Apple T2 HEVC Encoder" (`/dev/video2`, NV12/P010)
     and "Apple T2 Sidecar Encoder" (`/dev/video3`, H.264/HEVC). `/usr/bin/ffmpeg` with
     `hevc_v4l2m2m`/`h264_v4l2m2m` encoded 10 s of 1080p30 at 8 Mbit/s in ~4 s; ffmpeg's own device
     pick took the Sidecar encoder for both. `t2-ave-suspend.service` (ours, for upstream's
     `sleep.d` hook) runs `t2remote pre-suspend`/`post-resume` around sleep: two S3 cycles, the
     Sidecar device removed in 150 ms and both sessions back in ~0.1 s, encodes fine after, Touch
     ID fine. Encode only, not VA-API: Chromium/mpv/OBS don't use it; KaiT2en's Sunshine fork does.
   - The `ffmpeg` on the PATH here is Homebrew's (no VA-API, no hwaccels); `/usr/bin/ffmpeg` has
     VA-API, and the iGPU encodes and decodes HEVC through it (`renderD128`).
14. **The rest, each with its own clock**: `t2-sidecar` (2026-11-23), i915 PSR (`patches/runtime/i915`, 2026-12-08; the
   16,1's panel is on the dGPU, so low value; look at it with the dGPU work). Skip `t2-power-tune`/`t2-zone-power` until the dGPU
   work lands. New on 2026-11-11, not before 2026-12-11: `modules/apple-t2-bridge`,
   `modules/apple-t2-alsa-ucm-conf`.

Ours, no wait: boot the live ISO on linux-omarchy instead of linux-t2. (Done 2026-11-12:
`t2-dkms-guard` 0.2 aborts an upgrade that would leave a module out, and the dotfiles'
`t2-post-update-check` hook checks the T2 items after every `omarchy update`.)
