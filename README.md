<div align="center">

<img src="void/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="void">

# void

**Blank the screen. Kill the keyboard. Clean your Mac.**

[![Release](https://img.shields.io/github/v/release/santi-ug/void?style=flat-square&color=blue)](https://github.com/santi-ug/void/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey?style=flat-square)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-6-orange?style=flat-square)](https://swift.org)

</div>

---

Wiping a MacBook screen means dragging a cloth across a live trackpad and keyboard.
Windows move, text gets typed, something launches. void gives you one toggle that
turns the display black and stops every key from reaching any app until you turn it
back off.

---

## Features

* **Total keyboard lockout** — key presses, key releases, modifiers, and the media
  keys (brightness, volume, play/pause) are all swallowed at the system level.
* **Self-healing input tap** — macOS disables an event tap whose callback runs slow.
  void listens for that and re-arms itself, with a watchdog behind it in case the
  notification is ever dropped. It does not quietly stop blocking halfway through.
* **Off-main-thread by design** — the tap runs on its own thread, so the overlay's
  fade-in can't stall the callback into a timeout.
* **Brightness guard** — the overlay is pure black and your keyboard is off, so the
  on-screen toggle is the only way out. void refuses to start below 20% brightness
  rather than stranding you.
* **Tells you why** — if it can't block input, it says so instead of showing a black
  screen that isn't actually blocking anything.
* **Follows your pointer** — on a multi-monitor setup, void blanks the display the
  cursor is on.
* **Lives in the menu bar** — no Dock icon, no window in your way.
* **No dependencies, no network** — pure Swift against system frameworks.

---

## Requirements

| | |
|---|---|
| **macOS** | 26 (Tahoe) or later |
| **Permission** | Accessibility — required to block input |
| **To build** | Xcode 26 or later |

---

## Installation

### Homebrew (recommended)

```bash
brew install --cask santi-ug/tap/void
```

The tap is added automatically. Use the full `santi-ug/tap/void` name — plain
`void` is a different app in Homebrew's main cask repository.

To update or remove:

```bash
brew upgrade --cask santi-ug/tap/void
brew uninstall --cask santi-ug/tap/void
```

### Manual

1. Download `void-<version>.dmg` from the [latest release](https://github.com/santi-ug/void/releases/latest).
2. Open it and drag void into Applications.

---

## Granting Accessibility access

void blocks input through a CoreGraphics event tap, which macOS gates behind
Accessibility. Without it, void will refuse to start and say so.

1. Launch void. It will prompt on the first attempt to enter void mode.
2. System Settings → **Privacy & Security** → **Accessibility**.
3. Add void and switch it on, then authenticate.

> **This has to be redone after every update.** void is ad-hoc signed rather than
> notarized, so macOS binds the grant to that exact build. A new build gets a new
> identity and the old grant stops applying — while the switch still shows as on.
> Remove void from the list and add it back after upgrading. See
> [Troubleshooting](#troubleshooting).

### Gatekeeper on first launch

Because void is distributed outside the App Store and isn't notarized, macOS will
say it can't be verified:

1. Click **OK** on the warning.
2. System Settings → **Privacy & Security** → scroll to **Security**.
3. Next to *"void was blocked…"*, click **Open Anyway** and authenticate.

This is a one-time exception per build.

---

## Usage

1. Click the void icon in the menu bar.
2. Flip **Enter Void**. The screen goes black and the keyboard stops responding.
3. Wipe the screen.
4. Click the toggle again to come back.

**Your way out is the mouse.** The keyboard is off by design, so no key combination
will exit void mode — click the toggle in the middle of the black screen. The
trackpad still works, which is why the brightness guard exists: if you can't see the
toggle, you can't leave.

---

## Privacy

| | |
|---|---|
| Network requests | None |
| Telemetry / analytics | None |
| Keystrokes | Discarded, never inspected, never stored |
| Data written to disk | None |

The event tap callback returns `nil` for every key event without reading its
contents. void has no reason to know which key you pressed, and doesn't look.

---

## Troubleshooting

### The Accessibility toggle is on, but void won't enter

The most common problem, and it is almost always a stale grant after an update.
macOS ties an ad-hoc signed app's permission to that specific build, so a new
version silently invalidates it while still displaying as enabled.

1. System Settings → Privacy & Security → **Accessibility**
2. Select void, press **–**, then **+**, and re-add `/Applications/void.app`
3. Authenticate

If you have void in more than one place — `/Applications`, a build directory, a
clone of this repo — keep only the one you launch. They share a bundle identifier
and compete for the same grant.

### void refuses with a brightness message

Working as intended. Below 20% you wouldn't be able to see the toggle that gets you
out of a black screen with a dead keyboard. Raise the brightness and try again.

### Keys work again after a while

Fixed in 1.2.0. Earlier builds never handled macOS disabling the event tap, so the
lock silently lapsed mid-session. Update.

---

## Copyright

© 2026 Santiago Uribe. All rights reserved.

This source is published for reference. No licence is granted to use, copy, modify,
or distribute it. If you want to do any of those, get in touch.
