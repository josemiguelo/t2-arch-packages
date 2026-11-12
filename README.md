# t2-arch-packages

Arch/Omarchy packages of the T2 Mac drivers and tools from
[KaiT2en-Fedora](https://github.com/kaiT2en/KaiT2en-Fedora), for a stock
`linux-omarchy` kernel (no `linux-t2`). Tested on a MacBook Pro 16-inch 2019
(MacBookPro16,1).

This is an independent repackaging, not a KaiT2en project and not endorsed by
it. All driver and app code is KaiT2en's: kernel modules under GPL-2.0, userspace
under GPL-3.0-or-later with a section 7(b) author attribution term (André
Eikmeyer; 4f1sh3r for the fan and SMC tools). Each package ships KaiT2en's
`LICENSING.md` and `AUTHORS`. KaiT2en's name and logo are its trademarks; the
logo is removed from `t2-fan-control` and `t2-smc-control` (`no-wordmark.patch`).

## Use the repo

```bash
# Trust the signing key (fingerprint 077D 8295 CCF8 34D3 F5EC  25F7 0506 B72C 34EB 162F)
curl -fsSL https://github.com/josemiguelo/t2-arch-packages/releases/download/repo/t2-arch-packages.asc |
  sudo pacman-key --add -
sudo pacman-key --lsign-key 077D8295CCF834D3F5EC25F70506B72C34EB162F
# then install t2-arch-packages-keyring, which keeps the key trusted through
# `pacman-key --populate` (like archlinux-keyring). It is signed with this same
# key, so it cannot replace the two commands above on a first install: pacman
# would look the key up on a keyserver, where it is not published.

# /etc/pacman.conf
[t2-arch-packages]
Server = https://github.com/josemiguelo/t2-arch-packages/releases/download/repo
```

Then `sudo pacman -Sy linux-omarchy-headers t2bce-stack-dkms t2smc-dkms t2sbs-dkms t2smp-dkms t2thunderbolt-dkms t2-precision-trackpad-dkms t2-bluetooth-dkms t2-fan-control t2-smc-control t2bce-audio-ucm t2-dkms-guard t2-arch-packages-keyring linux-apfs-rw-dkms apple-bcm-firmware-fetcher` (`linux-apfs-rw-dkms`, the APFS driver the fetcher mounts the macOS volume with, is Arch's own in `[extra]`; the fetcher is in `[arch-mact2]`).
`linux-t2` must not be installed on the same kernel: it has its own t2bce. See
[Omarchy's `fix-t2.sh` on the `t2-kait2en` branch](#port-status) for the module,
initramfs and kernel-argument setup.

## Packages

| Package | Source in KaiT2en | Status |
|---|---|---|
| `t2bce-stack-dkms` | `modules/t2bce_*`, `t2-services/t2-ave/kernel/*` | **works on MacBookPro16,1**: keyboard/trackpad (incl. LUKS prompt), Touch Bar, audio device |
| `t2bce-audio-ucm` | `modules/t2bce_audio-alsa-ucm-conf/ucm2` | builds; replaces arch-mact2's older `t2bce_audio-alsa-ucm-conf` |
| `t2smc-dkms` | `modules/t2smc` | **works**: 2 fans, 50 temps, charge control on `BAT0`, rtc2, watchdog. Skips `applesmc` (fails `-EIO` on T2 with a stock kernel) on kernels that have `t2smc` |
| `t2sbs-dkms` | `modules/t2sbs` | **works**: capacity 98% (correct, `charge_now/charge_full`) vs stock `sbs` 78% (design-relative). Skips `sbs` on kernels that have `t2sbs` |
| `t2thunderbolt-dkms` | `modules/t2thunderbolt` | loads (4 PM ordering links on 2× Titan Ridge 4C); autoloads by NHI alias; no wake-time change on its own |
| `t2smp-dkms` | `modules/t2smp` | **works**: removes the slow early-resume CPU bring-up; part of the ~1 s wake |
| `t2-dkms-guard` | (this repo) | pacman PreTransaction hook: aborts a `linux-omarchy-headers` upgrade if any `# t2-arch-packages` DKMS module fails to build against the new headers (tested: pass, fail, no-op) |
| `t2-precision-trackpad-dkms` | `modules/t2_precision_trackpad` | compiles clean vs `linux-omarchy` 7.2.15. Multitouch/Force Touch for the internal trackpad: stock kernels drive it as a plain mouse (no two-finger scroll, no tap to click), `linux-t2` uses a patched `hid_magicmouse`. Must load before `t2bce_vhci` in the initramfs |
| `t2-bluetooth-dkms` | kernel.org 7.2.15 `drivers/bluetooth` + `patches/runtime/wireless/{0002,0012,0013,0021,0024}` | compiles clean vs `linux-omarchy` 7.2.15. Replaces `btbcm`, `hci_uart`, `hci_bcm4377`: stock `btbcm` drops these Macs' LE advertisements (320 "unknown advertising packet type" in one boot), so LE keyboards/mice don't appear or can't connect. 7.2.x `-omarchy` kernels only |
| `t2-arch-packages-keyring` | (this repo) | signing key in `/usr/share/pacman/keyrings`, populated on install |
| `t2-fan-control` | `apps/t2-fan-control` | **works** with the shipped `/etc/t2-fancontrol/config.txt` (system chill 80 °C). Upstream's default 45 °C pins MacBookPro16,1 fans at 100%. Paths moved `/usr/local` → `/usr`; replaces `t2fanrd` |
| `t2-smc-control` | `apps/t2-smc-control` | **builds**, upstream's 13 tests pass (2026-11-12). The GTK app and `t2-smc-gaugingd.service`, which lifts a charge limit (t2smc's `battery_charge_limit_suspended`) for a full charge when the gauge needs one to recalibrate, as macOS's powerd does. Paths moved `/usr/local` → `/usr`; the unit runs only where t2smc is loaded |

### Notes from testing (MacBookPro16,1)

- The T2 SMC keeps manual fan mode across reboots. To hand fans back: stop the
  daemon, then write `0` to each `fanN_target` of the `t2smc` hwmon.
- `modprobe -r sbs` also unloads `sbshc`; load it again before `insmod t2sbs.ko`.
- Charge limit writes (`charge_control_end_threshold`) not tested yet; the SMC
  may keep them across reboots.
- The fan daemon saves its config on every start. Running it before the package
  is installed leaves a `/etc/t2-fancontrol/config.txt` with upstream defaults,
  and pacman then puts the shipped config in `config.txt.pacnew`.

## Resume speed (MacBookPro16,1, linux-omarchy, 2026-11-08)

Kernel/journal timestamps are unreliable across S3 on this Mac; per-device
times come from `echo 1 > /sys/power/pm_print_times` (`returned 0 after N usecs`).

| Change | Result |
|---|---|
| `pm_async=1` (drop `pm_async=off`) | works; devices resume in parallel |
| `t2thunderbolt` | loads (4 PM ordering links), no wake-time change |
| `t2smp` | removes the slow early-resume CPU bring-up ("Enabling non-boot CPUs"); wake ~16 s |
| remaining | Titan Ridge TB upstream bridges ~10.8 s each (`pci_pm_resume_noirq`), TB NHIs ~5 s, chipset root port ~1.4 s, amdgpu ~1.1 s, t2smc ~1.1 s |
| `pci=noaer pcie_ports=compat` (+ `t2smp`, `pm_async=1`) | **wake ~1 s** (from ~16 s). Trade-off: no native PCIe hotplug on the TB ports |

Still seen after resume: `xHC error in resume ... Reinit` on the Titan Ridge xHCIs
(harmless), and once a brcmfmac firmware timeout + reload (Wi-Fi reconnected by
itself; 0 in 5 earlier resumes). If it recurs: KaiT2en's wireless patches or its
brcmfmac unload/reload around suspend (`kait2en-suspend.service`).

## Dual-kernel test setup (2026-11-08)

`linux-omarchy` + these packages next to `linux-t2` on one install works:
DKMS guarded by `BUILD_EXCLUSIVE_KERNEL=".*-omarchy$"`, `applesmc`/`sbs` skipped
only where `t2smc`/`t2sbs` exist, `t2fanrd` limited to `*-t2` kernels by a
drop-in, `t2smc?`/`t2sbs?` optional in mkinitcpio. Avoid
`KERNEL_CMDLINE["linux-omarchy"]` in Limine: it replaces the default cmdline.

## Keeping up with KaiT2en

`bin/kait2en-sync` carries KaiT2en's upstream work into the packages:

- `kait2en-sync check`: per package, the upstream commits since its pinned
  `_commit`, plus changes to KaiT2en's Fedora installer (`scripts/fedora`), to
  review by hand for `fix-t2.sh` (new kernel arguments, modules, services).
  Exit 10 when a package has updates.
- `kait2en-sync kernel`: builds every published DKMS package against the newest
  `linux-omarchy-headers` of this machine's `[omarchy]` channel, ahead of
  Omarchy shipping that kernel. Exit 1 when one doesn't build.
- `kait2en-sync notify`: for a timer: `check`, and `kernel` only when
  `[omarchy]` has headers it hasn't tested yet; desktop notifications for
  updates and for modules that don't build.
- `kait2en-sync apply`: for each package with upstream changes, pins the new
  commit, builds and signs it, builds its DKMS modules against the newest
  headers, then, after asking, publishes to the release (replacing the old
  versions) and commits and pushes the PKGBUILDs.

`t2-bluetooth-dkms` also tracks a kernel version (`_kver`): when
`linux-omarchy` moves to a new minor, `kernel` reports it skipped, and its
sources move to that release by hand.

## Build and release

Sources are pinned to a KaiT2en commit (`_commit` in each PKGBUILD) and fetched
from GitHub; `KAIT2EN_GIT=file:///path/to/clone` builds from a local checkout.

```bash
KEY=077D8295CCF834D3F5EC25F70506B72C34EB162F
for p in */; do (cd "$p" && PKGDEST=$PWD/../out makepkg -f --sign --key $KEY); done
cd out && repo-add --sign --key $KEY --verify t2-arch-packages.db.tar.zst *.pkg.tar.zst
# GitHub release assets cannot be symlinks
for l in t2-arch-packages.{db,files}{,.sig}; do cp --remove-destination "$(readlink -f $l)" $l; done
gh release upload repo --clobber *.pkg.tar.zst *.sig t2-arch-packages.{db,files}* t2-arch-packages.asc
```

## Port status

Omarchy integration lives on the `t2-kait2en` branch of an Omarchy clone
(`install/hardware/apple/fix-t2.sh`): these packages instead of `linux-t2`,
`t2smc`/`t2sbs` in the initramfs, kernel arguments `pci=noaer pcie_ports=compat`
without `pm_async=off`.

1. ✅ `t2bce-stack-dkms` (keyboard, trackpad, audio transport)
2. ✅ `t2smc`, `t2sbs` + fan control (replaces `t2fanrd`)
3. ✅ UCM · ⬜ DSP profile `16_1`
4. ✅ Suspend: deep S3, ~1 s wake (`t2smp`, `t2thunderbolt`, kernel arguments)
5. ⬜ `t2touchbar`, `t2gmux` + dGPU services, `t2bdrm` + Touch Bar app, trackpad actuator
6. ⬜ ACPI autofix (only if its log signatures appear)
7. ⬜ In-tree patch series (`patches/runtime/{wireless,gpu-runtime-pm}`)
