# KaiT2en on Omarchy: how the fork works and how to maintain it

State as of 2026-11-16 (first written 2026-11-12), on `t2-macbook-omarchy` (MacBookPro16,1),
Omarchy 4.5.0-3 stable, `linux-omarchy` 7.2.15. The owner-facing overview is the
[README](../README.md).

**In short:** the fork only matters while Omarchy is being installed. On the running system,
upstream Omarchy is in charge again, and what keeps the T2 setup intact is your package repo,
`t2-dkms-guard`, and the few T2 setup scripts in your dotfiles. Updates are safe as long as those three
keep doing their jobs. There are two real risks: the first 7.3 kernel, and future upstream
migrations that assume a T2 Mac runs `linux-t2`.

## 1. The four pieces

| Piece | What it does | When it acts |
|---|---|---|
| **t2-arch-packages** (`josemiguelo/t2-arch-packages`, a signed pacman repo) | KaiT2en's drivers and tools as Arch packages, and everything T2 that isn't configuration: the DKMS modules, the services and apps, the T2 panel on Omarchy's bar (`t2-omarchy-plugins` and a tab per package), the kernel arguments (`t2-kernel-args`), `t2-dkms-guard`, the keyring. Two meta-packages hold it together: `t2-mac` (every T2 Mac) and `t2-mac-hybrid` (hybrid graphics); a new package reaches installed Macs as a new dependency of them. [packages.md](packages.md) lists them all | Every time pacman installs or updates them, from the GitHub release `repo` |
| **omarchy fork**, branch `t2-kait2en-stable` (`josemiguelo/omarchy`) | Replaces upstream's T2 support (`linux-t2` plus `t2fanrd`) with stock `linux-omarchy` plus your packages: `install/hardware/apple/fix-t2.sh`, `install/hardware/pacman.sh`, the package list | **Only during installation** |
| **omarchy-iso fork**, branch `t2-kait2en` (`josemiguelo/omarchy-iso`) | Builds the ISO that runs that installer: picks `linux-omarchy` on T2 Macs, trusts your repo key, adds the repo to the ISO's pacman configs, populates hardware keyrings once the target's keyring is ready | Only when building the ISO and installing |
| **dotfiles** (`~/.local/share/chezmoi`, `loadouts/.etc/t2/`) | The `t2-*` scripts: the owner's options and setup only (the charge limit, which services run, Touch ID's PAM, the keyboard switch-over, Hybrid once); no software since 2026-11-16 | Whenever you run `loadout` (status, sync, run) |

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
     installer is still building the target's keyring), then `linux-apfs-rw-dkms` on its own
     (DKMS builds at the end of a transaction, and the firmware fetcher needs it), then `t2-mac`,
     and `t2-mac-hybrid` on the dual-GPU models. DKMS compiles the modules for the installed
     kernel.
   - **Boot setup:**
     - `/etc/mkinitcpio.conf.d/apple-t2.conf`: the initramfs modules.
       `t2_precision_trackpad` goes first so it claims the trackpad before `hid-apple` does, and
       `t2bce_vhci` is there so the keyboard works at the disk unlock prompt.
     - `t2-kernel-args --write`: `/etc/limine-entry-tool.d/t2-mac.conf`, the kernel arguments
       (`pci=noaer pcie_ports=compat` for the ~1 s wake, forced PCIe ASPM, ...). The package keeps
       the file that way afterwards, against anything that rewrites it.
     - `/etc/modules-load.d/t2.conf`: `t2bce_vhci`, `hci_bcm4377`.
   - **Services and rules:** the Wi-Fi firmware on the first boot, the fan daemon (80 °C system
     target), gauging, Touch ID, the Touch Bar, the keyboard backlight fade, True Tone, the ACPI
     fix's first-boot build, and the firewall rules for AirShare, AirDrop and Sidecar's Moonlight.
4. **The ISO's keyring step** trusts your repo key once the target's keyring is ready. Doing it
   earlier is what broke an install before.
5. **The first login** (`install/user/first-run/t2-omarchy.sh`) puts the T2 panel on the bar
   (`t2-omarchy-setup`: Omarchy loads third-party plugins only from the user's config).
6. **The dotfiles bootstrap** (`bootstrap.sh t2-macbook-omarchy`) runs the owner's T2 setup:
   keyboard swaps and fnmode, the Wi-Fi firmware fallback, the 90 % charge limit, Hybrid once,
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
the installed kernel (`linux-omarchy 7.2.15-1`). Upstream, KaiT2en had new commits for several
packages since their pin; `kait2en-sync check` lists them.

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

### C. The first kernel 7.3: held back until the package moves

- `t2-wireless-dkms` only builds for 7.2 kernels (`BUILD_EXCLUSIVE_KERNEL="^7\.2\.[0-9]+-[0-9]+-omarchy$"`).
  Booting 7.3 without it would mean the stock `btbcm`/`hci_uart`/`hci_bcm4377`, which drop this
  Mac's Bluetooth LE advertisements (**the Keychron K15 Max and the MX Master 3 would stop
  connecting**), and the stock `brcmfmac` (Wi-Fi without the resume fixes).
- Since `t2-dkms-guard` 0.2 (2026-11-12) the guard **aborts that upgrade** ("would be left out"),
  as it does for a module that fails to build, and the daily timer's kernel test warns ahead of
  it. Move the package to 7.3 sources, or hold the kernel (`IgnorePkg = linux-omarchy
  linux-omarchy-headers`), or let it through without the module:
  `sudo env T2_DKMS_GUARD_ALLOW_SKIP=1 pacman ...`. (0.1 let the upgrade through silently.)

### D. A future upstream migration that assumes "T2 means `linux-t2`": the other risk

Upstream has already shipped changes like this:

- **One rewrote the kernel arguments.** `1785944594` replaced `pcie_ports=compat` with
  `pm_async=off` in `t2-mac.conf`. Since 2026-11-16 the `t2-kernel-args` package puts the file
  back within a second and rebuilds the boot image, by itself (a path unit on the file, and a
  boot service).
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

It's automatic since 2026-11-12: the dotfiles' `t2-post-update-check` keeps a post-update hook
(`~/.config/omarchy/hooks/post-update.d/t2-loadout-check`) that runs `loadout status` for the T2
items (the repo, its key and hook, the stable channel, the keyboard settings, the Wi-Fi
firmware, the charge limit, the daemons) and sends a critical notification naming any the update
undid. `loadout run <name>` repairs one. The packages themselves no longer need it: `t2-mac` keeps
them installed, and the orphan cleanup can't remove what it depends on.

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
- When 7.3 headers appear, move `t2-wireless-dkms` to 7.3 sources (kernel.org 7.3 plus KaiT2en's
  patches) first. Until it's ready, hold the kernel back with
  `IgnorePkg = linux-omarchy linux-omarchy-headers` in `/etc/pacman.conf`.

### KaiT2en upstream

KaiT2en's changes come in as they land: a package may move to KaiT2en's newest real commit on
its paths. Read the commit (and its issues) before porting, and test on the Mac before
publishing. The candidates are in CLAUDE.md's Roadmap.

- `bin/kait2en-sync check`: what changed since each package's pinned commit, each commit marked
  `eligible` or `sweep`. `apply` re-pins each package to its own newest eligible commit (never
  backwards), builds, signs, tests DKMS against the newest headers, and publishes after asking.
  The daily `notify` only speaks for eligible updates. (`KAIT2EN_MIN_AGE_DAYS`, default 0, can hold
  recent commits back as `waiting`.) Read the `sweep` lines: the
  heuristic (a commit touching more than 8 `apps/`/`modules/` folders) can take a new feature for a
  sweep.
- Changes to KaiT2en's Fedora installer (`scripts/fedora`) don't reach you automatically: new
  kernel arguments, modules or services may belong in the fork's `fix-t2.sh`, by hand. On
  2026-11-12 there were 4 new ones (iMac Pro kernel arguments, GPU runtime power management).
  None affects the MacBookPro16,1 now, but the GPU work is the same area as the
  `amdgpu … sdma0` warning and the dGPU roadmap item.

### Publishing a package by hand

From [maintaining.md](maintaining.md) ("Build and release"), for one package added to the existing
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

