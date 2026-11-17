# Maintaining the repo

For whoever builds and publishes these packages. How the pieces fit together
over an install and an update is [omarchy-integration.md](omarchy-integration.md);
the per-package detail is [packages.md](packages.md).

## Keeping up with KaiT2en


`bin/kait2en-sync` carries KaiT2en's upstream work into the packages, **a
month late on purpose**: KaiT2en ships dangerous changes often, so a package
only moves to a KaiT2en commit that landed at least 30 days ago
(`KAIT2EN_MIN_AGE_DAYS`) and after which its paths stayed quiet for 30 days. A
follow-up sooner is a fix or a revert, and the clock restarts from it.
Repo-wide sweeps (a commit touching more than 8 `apps/` or `modules/` folders,
`KAIT2EN_SWEEP_DIRS`) are listed but don't restart it. Pins never move
backwards.

- `kait2en-sync check`: per package, the upstream commits since its pinned
  `_commit`, each marked `eligible`, `waiting` or `sweep`, the commit it would
  re-pin to, and the earliest day the waiting ones can qualify; plus changes to
  KaiT2en's Fedora installer (`scripts/fedora`), to review by hand for
  `fix-t2.sh` (new kernel arguments, modules, services). Exit 10 when a package
  has an eligible update.
- `kait2en-sync kernel`: builds every published DKMS package against the newest
  `linux-omarchy-headers` of this machine's `[omarchy]` channel, ahead of
  Omarchy shipping that kernel. Exit 1 when one doesn't build.
- `kait2en-sync notify`: for a timer: `check`, and `kernel` only when
  `[omarchy]` has headers it hasn't tested yet; desktop notifications for
  eligible updates and for modules that don't build.
- `kait2en-sync apply`: for each package with an eligible update, pins its
  eligible commit (each package its own), builds and signs it, builds its DKMS modules against the newest
  headers, then, after asking, publishes to the release (replacing the old
  versions) and commits and pushes the PKGBUILDs.

`t2-wireless-dkms` also tracks a kernel version (`_kver`): when
`linux-omarchy` moves to a new minor, `kernel` reports it left out and
`t2-dkms-guard` (0.2) holds that kernel back until its sources move to that
release by hand (`T2_DKMS_GUARD_ALLOW_SKIP=1` lets it through without it).

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

## History: resume speed (2026-11-08)


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

## History: the dual-kernel test setup (2026-11-08)


`linux-omarchy` + these packages next to `linux-t2` on one install works:
DKMS guarded by `BUILD_EXCLUSIVE_KERNEL=".*-omarchy$"`, `applesmc`/`sbs` skipped
only where `t2smc`/`t2sbs` exist, `t2fanrd` limited to `*-t2` kernels by a
drop-in, `t2smc?`/`t2sbs?` optional in mkinitcpio. Avoid
`KERNEL_CMDLINE["linux-omarchy"]` in Limine: it replaces the default cmdline.
