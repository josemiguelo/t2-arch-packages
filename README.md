# t2-arch-packages

Arch/Omarchy packages porting [KaiT2en-Fedora](https://github.com/kaiT2en/KaiT2en-Fedora)
T2 MacBook support to a stock `linux-omarchy` kernel (no `linux-t2`).

Personal port. KaiT2en's trademark terms forbid its name on published forks, and
its license requires keeping author attribution (see upstream `TRADEMARK.md`,
`LICENSING.md`). Rename before publishing anything.

## Packages

| Package | Source in KaiT2en | Status |
|---|---|---|
| `t2bce-stack-dkms` | `modules/t2bce_*`, `t2-services/t2-ave/kernel/*` | **works on MacBookPro16,1**: keyboard/trackpad (incl. LUKS prompt), Touch Bar, audio device |
| `t2bce-audio-ucm` | `modules/t2bce_audio-alsa-ucm-conf/ucm2` | builds; replaces arch-mact2's older `t2bce_audio-alsa-ucm-conf` |
| `t2smc-dkms` | `modules/t2smc` | **works** (live-tested on `linux-t2`): 2 fans, 50 temps, charge control on `BAT0`, rtc2, watchdog. Compiles clean vs `linux-omarchy` 7.2.15; blacklists `applesmc` (fails `-EIO` on T2 with a stock kernel) |
| `t2sbs-dkms` | `modules/t2sbs` | **works** (live-tested): capacity 98% (correct, `charge_now/charge_full`) vs stock `sbs` 78% (design-relative). Needs `sbshc` loaded; blacklists `sbs` |
| `t2thunderbolt-dkms` | `modules/t2thunderbolt` | loads (4 PM ordering links on 2× Titan Ridge 4C); autoloads by NHI alias; no wake-time change on its own |
| `t2smp-dkms` | `modules/t2smp` | **works**: removes the slow early-resume CPU bring-up; part of the ~1 s wake |
| `t2-dkms-guard` | (this repo) | pacman PreTransaction hook: aborts a `linux-omarchy-headers` upgrade if any `# t2-arch-packages` DKMS module fails to build against the new headers (tested: pass, fail, no-op) |
| `t2-fan-control` | `apps/t2-fan-control` | **works** with the shipped `/etc/t2-fancontrol/config.txt` (system chill 80 °C). Upstream's default 45 °C pins MacBookPro16,1 fans at 100%. Paths moved `/usr/local` → `/usr`; replaces `t2fanrd` |

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

## Build

```bash
cd t2bce-stack-dkms
makepkg -f            # KAIT2EN_REPO=<path> overrides the local KaiT2en clone
```

Sources are pinned to a KaiT2en commit (`_commit` in each PKGBUILD).

## Port order

1. `t2bce-stack-dkms` (keyboard, trackpad, audio transport)
2. `t2touchbar`, `t2smc`, `t2sbs` + fan control (replaces `t2fanrd`)
3. UCM + DSP profile `16_1`
4. Suspend (drop `pm_async=off`)
5. `t2gmux` + dGPU services, `t2bdrm` + Touch Bar app, trackpad actuator
6. ACPI autofix (only if its log signatures appear)
7. In-tree patch series (`patches/runtime/{wireless,gpu-runtime-pm}`)
