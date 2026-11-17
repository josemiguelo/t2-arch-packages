# T2 Macs on Omarchy

Everything an Intel Mac with Apple's T2 chip needs to run
[Omarchy](https://omarchy.org) well: the drivers and tools from
[KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora), packaged for Arch Linux
on Omarchy's stock `linux-omarchy` kernel, plus a T2 panel on Omarchy's bar and
an Omarchy installer that sets it all up.

It's in daily use on a MacBook Pro 16-inch 2019 (MacBookPro16,1): keyboard,
trackpad, Touch Bar, Touch ID, sound, Wi-Fi, Bluetooth, sleep, fans and both
GPUs work, and so do things the usual T2 setup doesn't have, like AirDrop,
True Tone and hybrid graphics.

This is an independent, personal project: not part of KaiT2en, Omarchy or
t2linux, and not endorsed by any of them.

## Why not `linux-t2`?

Omarchy's own T2 support installs `linux-t2`, a kernel patched for T2 Macs.
This repo does it the other way round: the stock kernel Omarchy ships for
everyone, with KaiT2en's T2 drivers built for it by DKMS. That gives you:

- **Omarchy's kernel and its updates**, the same as every other Omarchy machine.
- **KaiT2en's newer drivers and apps**, which go well beyond what `linux-t2`
  does: Touch ID, AirDrop and Quick Share, hybrid graphics, True Tone, the
  macOS speaker processing, and more (below).
- **A safety net for kernel updates:** a pacman hook refuses a kernel upgrade
  that would leave any T2 driver unbuilt, so an update can't leave you without
  a keyboard.

## Status at a glance

On the tested Mac, a MacBookPro16,1 (16-inch, 2019, Intel + AMD Radeon Pro
5300M/5500M). ✅ works, tested · ⚠️ works, with a catch · ❓ not tested yet.

| | Status | |
|---|---|---|
| Keyboard, incl. the disk unlock prompt | ✅ | |
| Keyboard backlight, idle fade | ✅ | |
| Trackpad: multitouch, palm rejection, Force Touch, haptics | ✅ | |
| Touch Bar | ✅ | |
| Touch ID: sudo, polkit, lock screen | ⚠️ | needs fingers enrolled in macOS; after a power loss, log into macOS once to unlock it |
| Speakers, with macOS-like sound | ✅ | the sound profile is the 16-inch 2019's |
| Microphones | ✅ | with KaiT2en's processing |
| Headphone jack | ✅ | |
| FaceTime camera | ✅ | |
| Wi-Fi | ✅ | firmware copied from macOS on the first boot |
| Bluetooth, incl. LE keyboards and mice | ✅ | |
| Sleep, ~1 s wake | ✅ | |
| Hibernation | ❓ | not tried |
| Battery percentage, charge limit, calibration | ✅ | |
| Fans | ✅ | |
| Hybrid graphics, Radeon off at idle | ✅ | dual-GPU MacBook Pros |
| Discrete graphics | ✅ | |
| External displays (Thunderbolt/USB-C) | ❓ | not tested; need Discrete mode (the ports are wired to the Radeon) |
| USB-C devices on every port | ✅ | |
| Thunderbolt docks, eGPUs | ❓ | not tested; can't be hot-plugged (part of the 1 s wake) |
| Idle power saving (Thunderbolt off, ASPM) | ✅ | |
| True Tone, auto-brightness | ✅ | |
| AirDrop (iPhone, Mac) | ✅ | cancel only stops waiting on this side |
| Quick Share (Android) | ✅ | Samsung phones show as "Android phone"; the hotspot fallback is untested |
| Second screen through Moonlight (Sidecar) | ✅ | |
| The T2 panel on the bar | ✅ | |
| Other T2 Macs | ❓ | see [Which Macs](#which-macs) |

## What works

What each of those gives you, in more detail.

| Area | What you get |
|---|---|
| **Keyboard** | Works everywhere, including the disk unlock prompt at boot, with `hid-apple`'s layout options (Fn/Ctrl, Option/Command). The keyboard backlight fades out after 30 s without input and comes back on the next keystroke. |
| **Trackpad** | Full multitouch (two-finger scroll, tap to click, gestures), palm rejection while typing, and Force Touch: a harder press gives a second, felt click from the Taptic Engine, and can run an action you choose (copy/paste, a key combo, a command). |
| **Touch Bar** | Dark until touched or Fn is held; media and F-key layers, swipes for volume and brightness, haptic feedback, and a "touch to unlock" prompt when Touch ID is waiting. |
| **Touch ID** | `sudo`, polkit prompts and the lock screen accept your fingerprint: the fingers you enrolled in macOS. |
| **Sound** | The speakers sound like they do in macOS: KaiT2en's recreation of macOS's speaker processing (EQ, crossovers, bass enhancement), for the 16-inch 2019's speakers. The microphones and the headphone jack work. |
| **Wi-Fi and Bluetooth** | Both work, with KaiT2en's fixes for Apple's Broadcom chips (waking from sleep, Bluetooth LE keyboards and mice). The firmware is copied from your macOS partition on the first boot. |
| **Sleep** | Deep sleep, and **waking takes about 1 second** (about 16 s before the tuning). |
| **Battery** | The correct percentage, a charge limit (so the battery isn't kept at 100 %), and the occasional calibration charge macOS would do. |
| **Fans** | A fan curve that keeps the Mac quiet at idle and cools hard under load, or the SMC's own control, as in macOS. |
| **Graphics** | **Hybrid graphics** on the dual-GPU MacBook Pros: the Intel GPU drives the screen and the Radeon powers off until an app asks for it. Idle battery draw went from **32 W to about 12 W**. The screen comes back properly after sleep, and its brightness is kept. Discrete mode (the Radeon for everything) is one switch away, for external displays. |
| **Power** | The idle Thunderbolt controllers power off and PCIe links save power, so the processor reaches deep idle states it never reached before. |
| **Camera** | The FaceTime HD camera works in any app. |
| **True Tone and auto-brightness** | The screen's white follows the room's light, from the T2's ambient light sensor, and brightness adjusts by itself, learning from your brightness keys. |
| **AirDrop and Quick Share** | Send to and receive from iPhones, iPads and Macs (AirDrop) and Android phones (Quick Share), while staying on your Wi-Fi network. |
| **A second screen, Sidecar-style** | A phone or tablet as an extra screen, or a mirror of this one, through [Moonlight](https://moonlight-stream.org). The T2 chip encodes the video, so the processor barely notices. |
| **The T2's own logs** | `t2journal` merges the T2 chip's logs with Linux's, for debugging. |
| **Fixes under the hood** | An ACPI fix that stops the firmware's processor tables from erroring at every boot. |

### The T2 panel

A single icon on Omarchy's bar opens a panel with a tab for each T2 feature
installed:

- **Battery:** charge, time left, power draw, the charge limit and battery health.
- **Fans:** fan speeds and temperatures, the fan curve or the SMC's control, the target temperature.
- **Graphics:** Hybrid or Discrete from the next boot, and whether the Radeon is asleep.
- **Trackpad:** click pressure, Force Click on or off, how hard, and its action.
- **Ambient Light:** True Tone, its strength, automatic brightness.
- **AirShare:** be visible to phones and Macs nearby, send files, the clipboard
  or the last screenshot, the files received lately, trusted devices.
- **Sidecar:** the second screen on or off, extended or mirrored, its size, pairing a new device.

The icon shows a dot while you're visible to AirDrop and Quick Share senders,
or while Sidecar is on. Everything also works from the command line.

## Which Macs

**Tested:** MacBookPro16,1 only. **Should work:** the other T2 Macs KaiT2en
supports, since the drivers are the same, but nobody has tried them with this
repo yet. A few parts are model-specific: the speaker sound profile is the
16-inch 2019's, and hybrid graphics is for the dual-GPU MacBook Pros (15,1,
15,3, 16,1, 16,4). If you try another model, an issue saying what works and
what doesn't is very welcome.

## Installing

**Keep macOS.** The Wi-Fi and Bluetooth firmware is copied from the macOS
partition, Touch ID uses the fingers enrolled in macOS, and macOS is how the
T2's own firmware gets updated. Install Linux beside it.

### A fresh install (recommended)

Omarchy installs from its own ISO. For T2 Macs there's a forked installer
([`josemiguelo/omarchy`](https://github.com/josemiguelo/omarchy), branch
`t2-kait2en-stable`) and ISO builder
([`josemiguelo/omarchy-iso`](https://github.com/josemiguelo/omarchy-iso),
branch `t2-kait2en`), which install these packages instead of `linux-t2` and
set everything up. No ISO is published yet; you build it yourself (Docker
needed, about 45 minutes):

```bash
git clone -b t2-kait2en-stable https://github.com/josemiguelo/omarchy.git
git clone -b t2-kait2en https://github.com/josemiguelo/omarchy-iso.git
git clone https://github.com/omacom/omarchy-pkgs.git
cd omarchy-iso
bin/omarchy-iso-make --local-source ../omarchy ../omarchy-pkgs --stable
# the ISO lands in release/*-local-stable.iso
```

Then, on the Mac:

1. In macOS, make room for Linux: free space or a new partition, in Disk Utility.
2. In macOS Recovery, open Startup Security Utility: set **No Security** and
   **allow booting from external media**. A T2 Mac won't boot a Linux ISO otherwise.
3. Write the ISO to a USB stick, start the Mac holding Option, pick the stick,
   and install as with any Omarchy ISO.
4. On the first login, Omarchy offers to set up the fingerprint reader: that's
   Touch ID. The T2 panel appears on the bar by itself.

### An existing Omarchy install

Not a tested path. Omarchy's own T2 setup (`linux-t2`) and this one can't share
a kernel, and the installer's T2 step
([`install/hardware/apple/fix-t2.sh`](https://github.com/josemiguelo/omarchy/blob/t2-kait2en-stable/install/hardware/apple/fix-t2.sh))
does more than install packages: initramfs modules, module options, services,
firewall rules. A fresh install from the ISO is much easier.

### Plain Arch, or just the packages

Add the repo and install the meta-package, plus the hybrid one on a dual-GPU
MacBook Pro:

```bash
# Trust the signing key (fingerprint 077D 8295 CCF8 34D3 F5EC  25F7 0506 B72C 34EB 162F)
curl -fsSL https://github.com/josemiguelo/t2-arch-packages/releases/download/repo/t2-arch-packages.asc |
  sudo pacman-key --add -
sudo pacman-key --lsign-key 077D8295CCF834D3F5EC25F70506B72C34EB162F

# /etc/pacman.conf
[t2-arch-packages]
Server = https://github.com/josemiguelo/t2-arch-packages/releases/download/repo

sudo pacman -Sy t2-mac            # every T2 Mac
sudo pacman -S t2-mac-hybrid      # dual-GPU MacBook Pros: hybrid graphics
```

The packages target `linux-omarchy` (the DKMS modules build only for it) and
the Limine bootloader (the kernel arguments). `fix-t2.sh` above is the
reference for the rest of the setup. `linux-t2` must not be installed at the
same time.

## Updates

- **Omarchy updates** work as usual. The T2 packages come from this repo next
  to Omarchy's, and `t2-mac` pulls in any T2 package added later.
- **Kernel updates are guarded:** if a new `linux-omarchy` would leave a T2
  driver unbuilt, the upgrade stops and you stay on the kernel that works. The
  move to each new kernel series (7.3 next) is done here first; then the guard
  lets it through.
- **KaiT2en's changes come in as they land:** a daily check lists KaiT2en's new
  commits per package, and they're packaged and tested here before they're
  published.

## Known limits

- **One model tested** (above).
- **Samsung phones show as "Android phone"** when you send with Quick Share:
  they hide their name, even when visible to everyone.
- **External displays on the Thunderbolt ports need Discrete graphics** (the
  Graphics tab, then a reboot).
- **Panel self refresh stays off** on the dual-GPU MacBook Pros: with it, the
  screen doesn't come back after sleep.
- **No native PCIe hotplug on the Thunderbolt ports**, the price of the 1 s
  wake: Thunderbolt docks and eGPUs aren't hot-pluggable. USB-C devices work.
- **AirDrop's cancel** stops waiting on this side; a transfer the other device
  already accepted may still finish.

## Credits and licensing

All driver and app code is [KaiT2en](https://github.com/kaiT2en/KaiT2en-Fedora)'s,
by André Eikmeyer and 4f1sh3r (the fan and SMC tools): kernel modules under
GPL-2.0, userspace under GPL-3.0-or-later with a section 7(b) attribution term.
Each package ships KaiT2en's `LICENSING.md` and `AUTHORS`. KaiT2en's name and
logo are its trademarks: the logo is removed from the apps, and the packages use
their own names. `bankstown-lv2` is chadmed's (Asahi Linux), MIT. The Wi-Fi
firmware fetcher is t2linux's. Sunshine (`sunshine-t2`) is LizardByte's, with
the V4L2 encoder KaiT2en contributed. The packages this repo writes itself (the
T2 panel, the Omarchy integration, the helpers and patches) are
GPL-3.0-or-later.

## More detail

- [docs/packages.md](docs/packages.md): every package, where it comes from, and
  how it was tested.
- [docs/omarchy-integration.md](docs/omarchy-integration.md): how the installer,
  the ISO and this repo fit together over an install and an update.
- [docs/maintaining.md](docs/maintaining.md): keeping up with KaiT2en, building
  and publishing.
