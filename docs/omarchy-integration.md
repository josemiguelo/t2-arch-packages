# KaiT2en on Omarchy: how the fork works and how to maintain it

State as of 2026-11-12, on `t2-macbook-omarchy` (MacBookPro16,1), Omarchy 4.5.0-3 stable,
`linux-omarchy` 7.2.15.

**In short:** the fork only matters while Omarchy is being installed. On the running system,
upstream Omarchy is in charge again, and what keeps the T2 setup intact is your package repo,
the T2 scripts in your dotfiles, and `t2-dkms-guard`. Updates are safe as long as those three
keep doing their jobs. There are two real risks: the first 7.3 kernel, and future upstream
migrations that assume a T2 Mac runs `linux-t2`.

## 1. The four pieces

| Piece | What it does | When it acts |
|---|---|---|
| **t2-arch-packages** (`josemiguelo/t2-arch-packages`, a signed pacman repo) | KaiT2en's drivers and tools as Arch packages: 7 DKMS kernel-module packages (`t2bce-stack`, `t2smc`, `t2sbs`, `t2smp`, `t2thunderbolt`, `t2-precision-trackpad`, `t2-bluetooth`), `t2-fan-control`, `t2-smc-control`, `t2-dsp` (with `bankstown-lv2`), `t2bce-audio-ucm`, `t2-dkms-guard`, the keyring | Every time pacman installs or updates them, from the GitHub release `repo` |
| **omarchy fork**, branch `t2-kait2en-stable` (`josemiguelo/omarchy`) | Replaces upstream's T2 support (`linux-t2` plus `t2fanrd`) with stock `linux-omarchy` plus your packages: `install/hardware/apple/fix-t2.sh`, `install/hardware/pacman.sh`, the package list | **Only during installation** |
| **omarchy-iso fork**, branch `t2-kait2en` (`josemiguelo/omarchy-iso`) | Builds the ISO that runs that installer: picks `linux-omarchy` on T2 Macs, trusts your repo key, adds the repo to the ISO's pacman configs, populates hardware keyrings once the target's keyring is ready | Only when building the ISO and installing |
| **dotfiles** (`~/.local/share/chezmoi`, `loadouts/.etc/t2/`) | The `t2-*` scripts: re-check and repair the T2 setup on the running system | Whenever you run `loadout` (status, sync, run) |

The omarchy fork has one branch, `t2-kait2en-stable` (its default on GitHub): the T2 commits on
the commit Omarchy's stable package is built from (the `_commit` in omarchy-pkgs'
`pkgbuilds/omarchy/PKGBUILD`). **The Mac's ISO is built from it, with `--stable`.** This is a
personal project and nothing goes upstream, so there's no branch on upstream's `quattro` (one
existed until 2026-11-12). The omarchy-iso fork also has one branch, `t2-kait2en`: the ISO builder,
whose `--stable` produces stable ISOs.

## 2. What happens during an install

1. **The ISO** boots `linux-t2`, because the live system needs it for the keyboard. Your repo's
   key is already trusted in the image. The installer picks `linux-omarchy` for the installed
   system.
2. **The fork's `pacman.sh`** adds `[t2-arch-packages]` to `/etc/pacman.conf`.
3. **The fork's `fix-t2.sh`**, when it detects PCI ID `106b:1801/1802`, sets up:
   - **Packages:** the keyring first (with `--noscriptlet` during an ISO install, because the
     installer is still building the target's keyring), then `linux-omarchy-headers`, the 7 DKMS
     packages, `t2-fan-control`, `t2-smc-control`, `t2bce-audio-ucm`, `t2-dsp`, `t2-dkms-guard`,
     `linux-apfs-rw-dkms` and `apple-bcm-firmware-fetcher` (from `[arch-mact2]`). DKMS compiles
     the modules for the installed kernel.
   - **Boot setup:**
     - `/etc/mkinitcpio.conf.d/apple-t2.conf`: the initramfs modules.
       `t2_precision_trackpad` goes first so it claims the trackpad before `hid-apple` does, and
       `t2bce_vhci` is there so the keyboard works at the disk unlock prompt.
     - `/etc/limine-entry-tool.d/t2-mac.conf`: the kernel arguments
       `intel_iommu=on iommu=pt mem_sleep_default=deep pci=noaer pcie_ports=compat` (the ~1 s
       wake, together with `t2smp`).
     - `/etc/modules-load.d/t2.conf`: `t2bce_vhci`, `hci_bcm4377`.
   - **Services and rules:**
     - `t2-wifi-firmware.service` plus `/usr/local/sbin/t2-wifi-reload`: on the first boot,
       copy the Wi-Fi firmware off the macOS volume, then bring the card up on it.
     - `t2-fancontrol.service`, with an 80 °C system target.
     - `t2-smc-gaugingd.service`: calibration charges under a charge limit.
     - `/etc/udev/rules.d/90-t2-ibridge-unmanaged.rules`: NetworkManager leaves the T2's
       internal USB network link (`05ac:8233`) alone.
4. **The ISO's keyring step** trusts your repo key once the target's keyring is ready. Doing it
   earlier is what broke an install before.
5. **The dotfiles bootstrap** (`bootstrap.sh t2-macbook-omarchy`) runs the T2 scripts, which
   check all of the above and add what no installer writes: keyboard swaps and fnmode, the gmux
   backlight, the EC clock, the render GPU, the Wi-Fi firmware fallback, the 85% charge limit,
   the stable channel, the repo guard.

## 3. After the install, the fork is gone from the system

The first `omarchy update` replaces the fork's `omarchy 4.5.0-2` with upstream's stable package.
Upstream's `fix-t2.sh` is on disk from then on, but install scripts never run again. What
survives is everything the fork's `fix-t2.sh` left behind: packages, files in `/etc`, enabled
services and the repo entry.

So from then on **upstream Omarchy changes the system without knowing about your setup.** It
assumes a T2 Mac runs `linux-t2`. Its own migration `1789325478` says *"T2 Macs must keep their
specialized kernel"* and decides that by checking for `linux-t2`.

## 4. What happens at an update

On 2026-11-12 nothing was waiting on the system: `checkupdates` was empty and the repos offered
the installed kernel (`linux-omarchy 7.2.15-1`). Upstream, KaiT2en had commits for six packages
since their pin, all younger than a month: none eligible before 2026-12-08 (`t2-bluetooth-dkms`
not before 2026-12-11).

### A. An ordinary `omarchy update`, no kernel change: safe

- **Package updates:** upstream packages update normally. Yours only change when you publish new
  builds to the release.
- **Migrations:** the 218 existing ones are marked done (the installer records them all); only
  migrations added in new releases run.
- **Orphan cleanup:** `omarchy-update-orphan-pkgs -y` removes every `pacman -Qtdq` package
  without asking. It won't touch the T2 stack: all 16 T2 packages are explicitly installed.
- **`pacman.conf` rewrites:** if an update, a channel switch or `omarchy refresh pacman` rewrites
  it, `~/.config/omarchy/hooks/pre-refresh-pacman.d/t2-arch-packages` (written by the dotfiles'
  `t2-arch-packages-repo`) adds `[t2-arch-packages]` back.

### B. A kernel update within 7.2 (7.2.16 and so on): guarded

- **`t2-dkms-guard` runs before pacman changes anything.** It's a pacman hook on
  `linux-omarchy-headers` (`/usr/share/libalpm/hooks/60-t2-dkms-guard.hook`). It extracts the new
  headers from the download cache and compiles every module whose `dkms.conf` is marked
  `# t2-arch-packages`.
- **If any module fails, the whole update is aborted** and you stay on the working kernel.
  Without `t2bce_vhci` there would be no keyboard to type the disk password.
- **If all build, the update goes ahead** and DKMS installs the modules for the new kernel.
- To override: `sudo env T2_DKMS_GUARD_SKIP=1 pacman -Syu`. Not yet tested through a real kernel
  upgrade.

### C. The first kernel 7.3: the gap

- `t2-bluetooth-dkms` only builds for 7.2 kernels (`BUILD_EXCLUSIVE_KERNEL="^7\.2\.[0-9]+-[0-9]+-omarchy$"`).
  For a 7.3 kernel the guard prints *"not for 7.3…, skipped"* and **lets the upgrade through**.
- You'd boot 7.3 with the stock `btbcm`/`hci_uart`/`hci_bcm4377`, which drop this Mac's
  Bluetooth LE advertisements. **The Keychron K15 Max and the MX Master 3 would stop
  connecting.**
- "Make `t2-dkms-guard` warn when a kernel skips a package" is on the roadmap in
  t2-arch-packages' CLAUDE.md. It hasn't been done yet.

### D. A future upstream migration that assumes "T2 means `linux-t2`": the other risk

Upstream has already shipped changes like this:

- **One rewrote the kernel arguments.** `1785944594` replaced `pcie_ports=compat` with
  `pm_async=off` in `t2-mac.conf`. The dotfiles' `t2-kernel-args` catches this, but **only when
  you run loadout**, not by itself.
- **One rewrote the module list.** `1785273276` changed `apple-t2.conf`.
- **A new one could install `linux-t2`.** It conflicts with the DKMS `t2bce` (both drive the same
  device), and Omarchy's boot order puts `linux-t2` first
  (`BOOT_ORDER="linux-t2, linux-omarchy, …"` in `/etc/limine-entry-tool.d/omarchy-defaults.conf`),
  so it would become the default boot entry.

There's no pre-update hook (only `post-update`). `omarchy-update` runs `omarchy-migrate` straight
after the new `omarchy` package is installed, so migrations can't be reviewed inside the update
itself. They can be spotted early: stable releases trail upstream's `quattro`, and the fork has
`quattro` as `upstream`.

## 5. How to maintain it

### After every `omarchy update`

Run `loadout status`. It re-checks the repo, its key and its hook, the kernel arguments, the
stable channel, the keyboard settings, the Wi-Fi firmware, the charge limit, the gauging daemon
and the network rule. `loadout run <name>` repairs whatever drifted.

### Before updating, now and then

Look for upcoming upstream migrations that touch T2 Macs:

```bash
git -C ~/Repos/gh/josemiguelo/omarchy fetch upstream
git -C ~/Repos/gh/josemiguelo/omarchy log --oneline -G '106b:180|linux-t2|t2-mac' upstream/quattro -- migrations
```

If a new one shows up, read it before the stable release that includes it reaches you.

### Kernels

- Watch for the daily `kait2en-sync.timer` notification (`bin/kait2en-sync notify`). It compiles
  the published DKMS packages against new `[omarchy]` headers as soon as they appear, ahead of you
  updating. `bin/kait2en-sync kernel` does the same by hand.
- When 7.3 headers appear, move `t2-bluetooth-dkms` to 7.3 sources (kernel.org 7.3 plus KaiT2en's
  patches) first. Until it's ready, hold the kernel back with
  `IgnorePkg = linux-omarchy linux-omarchy-headers` in `/etc/pacman.conf`.

### KaiT2en upstream

**Wait a month.** KaiT2en ships dangerous changes often. Nothing is ported, re-pinned or added
until the KaiT2en commit that brings it is at least 30 days old and the paths it touches have had
no further real change for 30 days (repo-wide sweeps such as lockfile alignment don't count;
"fix"/"revert" follow-ups do, and restart the clock). Pin to that commit, never to KaiT2en's HEAD,
and read the month of history after it before porting. Only a security fix, or a fix for a bug
this Mac actually hits, goes sooner, and only by an explicit decision. The candidates and their
earliest dates are in CLAUDE.md's Roadmap.

- `bin/kait2en-sync check`: what changed since each package's pinned commit, each commit marked
  `eligible`, `waiting` (with the earliest day it can qualify) or `sweep`. `apply` re-pins each
  package to its own eligible commit (never backwards), builds, signs, tests DKMS against the
  newest headers, and publishes after asking. The daily `notify` only speaks for eligible
  updates. `KAIT2EN_MIN_AGE_DAYS` (default 30) is the rule's length. Read the `sweep` lines: the
  heuristic (a commit touching more than 8 `apps/`/`modules/` folders) can take a new feature for a
  sweep.
- Changes to KaiT2en's Fedora installer (`scripts/fedora`) don't reach you automatically: new
  kernel arguments, modules or services may belong in the fork's `fix-t2.sh`, by hand. On
  2026-11-12 there were 4 new ones (iMac Pro kernel arguments, GPU runtime power management).
  None affects the MacBookPro16,1 now, but the GPU work is the same area as the
  `amdgpu … sdma0` warning and the dGPU roadmap item.

### Publishing a package by hand

From the t2-arch-packages README ("Build and release"), for one package added to the existing
database:

1. Build: `makepkg -d -f` in the package folder (`-d` because Rust comes from rustup or mise,
   not pacman).
2. Download the release's `t2-arch-packages.*` into an empty folder, add the package, sign it
   (`gpg -u <key> --detach-sign`), then
   `repo-add --sign --key <key> --verify t2-arch-packages.db.tar.zst <pkg>`.
3. Replace the `.db`/`.files` symlinks with real files (release assets can't be symlinks).
4. Upload the package, its `.sig` and the `.db`/`.files` files, **without** the `.old` backups
   that `repo-add` leaves.
5. GitHub's CDN serves the old database for about a minute. Then `omarchy update` (a plain
   `omarchy pkg add` doesn't refresh package lists) and install.

### Before the next ISO build

- At each Omarchy release, rebase `t2-kait2en-stable` onto the commit the new stable package is
  built from. All of upstream's changes since the last release arrive then, at once: watching
  `upstream/quattro`'s migrations (above) gives the warning in advance.
- Build with `--stable` (the command is in the dotfiles' `docs/t2-macbook.md`). Before booting
  the stick, check it lists `omarchy-settings`, not `omarchy-settings-dev`.

### Never

- **Erase or reformat the macOS volume.** It's the only legal source of the Wi-Fi firmware; the
  fallback is the old `apple-bcm-firmware` package kept in 1Password.
- **Let the firmware fetcher become a dependency** (`pacman -D --asdeps`). The orphan cleanup
  would remove it.
- **Install `linux-t2` next to the DKMS stack.**

### Long term

This is a personal project: nothing goes upstream to omacom or KaiT2en (KaiT2en's README rejects
AI-written contributions anyway).

## 6. Possible follow-ups (not set up)

- A `post-update` hook (`~/.config/omarchy/hooks/post-update.d/`) that runs `loadout status` for
  the T2 items and sends a notification when something drifted, so you don't have to remember.
- `t2-dkms-guard` warning (or failing) when it skips a module, to close the 7.3 gap.
- Packaging the firmware fetcher in t2-arch-packages, to drop the unsigned `[arch-mact2]` repo
  (`SigLevel = Never`) from installed systems.
