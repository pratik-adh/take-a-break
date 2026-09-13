# Downtime

[![Build](https://github.com/pratik-adh/downtime/actions/workflows/build.yml/badge.svg)](https://github.com/pratik-adh/downtime/actions/workflows/build.yml)

**A macOS app that's concerned about your health.**

It sits in your menu bar and looks after the three things a long day at a
computer quietly takes from you - your eyes, your back, and your hydration -
by telling you to stand up, drink water, and look away from the screen _before
your body has to tell you itself._

It keeps a live countdown next to the clock. When a timer runs out it puts a
break card on screen: what to do, how long, and a ring counting the break down.
You can snooze it, skip it, or let it finish on its own.

```
menu bar:    👁 20m        ← next reminder, counting down
click:       dashboard - rings, toggles, water tracker, streak
right-click: break now · pause · settings · quit
```

**No Dock icon. No account. No analytics or telemetry - nothing you do here ever leaves your Mac.**

---

## What it's looking after

A full day at a screen is a slow accumulation of small strains. This app is
built around the three that are easiest to prevent and easiest to ignore:

|                                  | The problem                                                                                                                                                   | What the app does                                                                                                                                 |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| 👁 **Your eyes**                 | Screens cut your blink rate by about half, and hours of fixed-distance focus leaves eyes dry, tired and sore - the cluster usually called digital eye strain. | Nudges you every 20 minutes to look ~20 feet away for 20 seconds and blink - the optometrist's **20-20-20 rule**, built in as a one-click preset. |
| 🚶 **Your back and circulation** | Sitting still for hours stiffens hips and shoulders, loads your lower back, and is the part of desk work your body complains about years later.               | Reminds you to stand, straighten, reach and actually walk a few steps - movement, not just a stretch in your chair.                               |
| 💧 **Your hydration**            | Thirst usually shows up as tiredness and a headache first, so you reach for another coffee instead of water.                                                  | A gentle nudge to refill, plus a daily glass tracker so you can see whether you actually drank.                                                   |

None of this is medical advice - it's the ordinary, well-worn desk-health
guidance, made hard to forget.

---

## Why another reminder app

Most break reminders fail in one of two ways. Either they nag on a dumb wall
clock - firing while you're in a meeting, or thirty seconds after you sat back
down from lunch - or they're so easy to dismiss that you reflexively swat them
away without ever taking the break.

Downtime tries to earn the interruption instead:

- **It only counts time you were actually at the screen.** Step away and the
  timers hold. Stay away long enough and they reset and you get credit - so
  coming back from lunch doesn't mean an instant reminder.
- **It knows when to stay quiet.** Optional work hours, optional fullscreen
  detection, optional calendar-awareness (it holds during a meeting), and a
  pause button with real durations.
- **It tells you what to do, not just that time passed.** Each break names the
  action - stand and reach, drink a few mouthfuls, look 20 feet away - and the
  copy uses your real screen time, not a placeholder.
- **It keeps score, locally.** Breaks taken, skipped and snoozed, plus a streak,
  so the habit is visible without a dashboard in the cloud.

---

## The three reminders

Each runs on its own timer and can be turned off independently.

| Reminder            | Default interval | Default break | What it asks                              |
| ------------------- | ---------------- | ------------- | ----------------------------------------- |
| **Stand & Stretch** | every 1 hour     | 3 min         | stand up, roll your shoulders, walk a bit |
| **Drink Water**     | every 45 min     | 30 s          | refill and actually drink                 |
| **Rest Your Eyes**  | every 20 min     | 20 s          | look ~20 ft away and blink                |

Intervals: 20 / 30 / 45 min · 1 / 1.5 / 2 / 3 / 4 / 5 hours.
Break lengths: 20 s / 30 s / 1 / 2 / 3 / 5 / 10 min.

There's a one-click **Apply the 20-20-20 rule** button in Settings → Reminders:
every 20 minutes, look 20 feet away, for 20 seconds - the optometrist's version
of the eye break.

When two reminders come due together, you get **one** card and the other is
marked as served - but only if the break is long enough to cover it, so nothing
reappears thirty seconds later.

---

## Feature tour

**Menu bar** - a live countdown to the next reminder, in monospaced digits so it
doesn't jitter as it ticks. Seconds optional, or hide the countdown entirely and
keep just the icon. When the dashboard is open and the item resizes underneath
it - a countdown collapsing to a bare paused icon - the popover re-centres on it
rather than being left stranded off-anchor.

**The dashboard** (left-click) - a ring counting down to whatever is next, a row
per reminder with its own progress ring and on/off switch, a water tracker,
Break now, today's stats, and a 7-day bar chart with your streak.

**Break screen** - three styles, from a small corner card to a full dim that
won't let you skip. Shows a countdown ring, what to do, an optional wellbeing
tip, and snooze/skip/done.

**Snooze** - default 10 minutes, capped at 3 per break by default so it can't
become a reflex. Other lengths available without opening Settings.

**Quiet by default when you're not there** - idle detection, screen lock and
display sleep all hold the timers; a long enough absence counts as a break.

**Work hours** - optional weekday + time window, overnight windows handled
correctly.

**Stats** - breaks taken / skipped / snoozed, break time, screen time and
glasses per day, kept for 120 days, with a streak counter.

**Custom wording** - rewrite any reminder's headline and message, with
`{duration}`, `{minutes}`, `{time}` and `{count}` placeholders filled in for
real.

**Light and dark** - the palette is defined as appearance-aware design tokens,
with a darker, more saturated set of brand hues for light mode so nothing reads
as washed out on a white background.

**Calendar-aware pausing** - optionally holds reminders while an event on your
calendar is happening right now, so a meeting never gets interrupted. Off by
default; asks for Calendar access only if you turn it on.

**Notification break style** - a fourth break style that sends a native macOS
notification with Done / Snooze / Skip actions instead of taking over the
screen, for anyone who finds the overlay too heavy.

**Shortcuts support** - "Take a Break Now," "Pause Reminders," "Resume
Reminders," and "Log a Glass of Water" are all exposed as Shortcuts/Siri
actions.

**Settings backup** - export your settings to a file and import them again, to
move your setup to another Mac or keep a copy.

**Deeper stats** - a week-over-week trend (breaks and compliance vs. the
previous 7 days) and a separate streak for each reminder, not just an overall
one.

**Network usage tracking** - optional, on by default, and deliberately kept as
a _separate feature_ from break reminders: its own menu bar icon, its own
pause switch, its own settings tab. The menu bar shows a total (today / this
week / this month, your choice) rather than a constantly-flickering live
rate; click the icon for a popover with live up/down speed rings, a **Test
Speed** button for a real download/upload/ping test, and a Wi-Fi-ranked usage
breakdown. Today's / this week's / this month's / all-time upload and
download totals, an optional breakdown by Wi-Fi network (needs Location
access - see [Privacy](#privacy)), and a daily data budget that sends one
nudge notification when you cross it. Downtime can't actually block or
throttle your connection (that needs a much deeper system integration), so
this is a nudge, not an enforced limit. **"Quit Network Mode"** - from
Settings, the icon's own right-click menu, or the popover footer - stops
tracking and makes its icon disappear entirely; the break reminder icon and
its own separate "Quit Break Mode" are untouched either way. Quitting one
feature never takes the other down with it, and only the break icon's menu
has the real "Quit Downtime" that ends the app.

📖 **[Full feature reference → FEATURES.md](FEATURES.md)** - every setting,
every default, and the exact behaviour behind each one.

---

## Install

You need **macOS 13 (Ventura) or later** and the Xcode Command Line Tools. You do
**not** need full Xcode.

```sh
xcode-select --install     # once, if `swift` isn't on your PATH

git clone https://github.com/pratik-adh/take-a-break.git
cd take-a-break
./build.sh --install       # compile, bundle, move to /Applications, launch
```

Or build without installing:

```sh
./build.sh
open "dist/Downtime.app"
```

The first launch puts a cup icon in your menu bar and nothing in the Dock -
that's deliberate (`LSUIElement`). Quit from the menu bar item.

Everything is Swift Package Manager, so `swift build -c release` on its own works
too; `build.sh` only adds the `.app` wrapper, the icon, and an ad-hoc signature.

> **Unsigned build note:** this is ad-hoc signed, not notarized. macOS may warn
> on first launch - right-click the app → Open, or allow it in
> System Settings → Privacy & Security.

---

## Privacy

Downtime makes no outbound network requests **except one, and only when you
ask for it**: tapping "Test Speed" in the network popover. There is no way to
measure real internet throughput without moving real bytes across the
internet, so that one feature briefly downloads/uploads test data to
Cloudflare's public speed-test endpoints (the same infrastructure behind
speed.cloudflare.com) - nothing personal attached beyond what any ordinary
HTTPS request carries, and nothing runs unless you tap the button. Everything
else - analytics, accounts, telemetry, update checks, background requests -
stays exactly as absent as before, and everything it reads or stores stays on
your Mac.

- Settings live in your user defaults under `com.downtime.mac`.
- History (including network usage totals) lives in
  `~/Library/Application Support/Downtime/stats.json`.
- Settings → Stats has an **Erase all history** button.

**Permissions:**

- Idle detection uses `CGEventSource.secondsSinceLastEventType`, which needs
  **no Accessibility grant**.
- Network usage tracking reads the same local interface byte counters Activity
  Monitor does (`sysctl`) - **no permission prompt, no data ever sent anywhere.**
- Calendar-aware pausing asks for a system permission (Calendar access), and
  only if you turn it on in Settings → Schedule. Events are only ever checked
  locally to see if one is happening right now - never read in bulk, stored,
  or sent anywhere.
- Breaking down network usage by Wi-Fi network (Settings → Network, off by
  default) asks for **Location Services** access - the only way macOS lets any
  app read the current Wi-Fi name, since Catalina, because a network name can
  reveal where you are. It's used only to label your own local usage history;
  nothing about it is ever stored beyond a per-network byte total, or sent
  anywhere.
- The Notification break style asks for the standard notification permission
  the first time you pick it.

---

## Source layout

```
Package.swift
build.sh                        compile → "Downtime.app" (icon, ad-hoc signature)
Resources/
  Info.plist                    LSUIElement, bundle id com.downtime.mac
  icon_1024.png                 source art; build.sh turns it into AppIcon.icns
  MakeIcon.swift                redraws icon_1024.png from code (CoreGraphics)
Sources/Downtime/
  main.swift                    NSApplication bootstrap, accessory policy
  AppDelegate.swift             wires the model to the four controllers
  Models/
    ReminderKind.swift          the three reminders: copy, colours, tips
    Settings.swift              preferences, presets, forgiving decode
    Stats.swift                 daily history, streaks, per-network JSON store
  Core/
    AppModel.swift              the engine: tick loop, breaks, snooze, pause
    SystemMonitor.swift         input idle time, screen lock/sleep, fullscreen
    CalendarMonitor.swift       EventKit: is a calendar event happening now?
    NetworkMonitor.swift        sysctl interface byte counters (up/down)
    WiFiMonitor.swift           CoreWLAN + CoreLocation: current Wi-Fi name
    NetworkReachability.swift   NWPathMonitor: is there a network path at all?
    SpeedTestService.swift      the one place this app makes a network request
    NotificationManager.swift   UNUserNotificationCenter for the Notification break style
    AppShortcuts.swift          App Intents for Shortcuts/Siri
    DesignTokens.swift          appearance-aware colour tokens
    Format.swift                durations, countdowns, bytes, message placeholders
    SoundPlayer.swift           system sounds
    LaunchAtLogin.swift         SMAppService + LaunchAgent fallback
  UI/
    StatusItemController.swift  break icon: countdown, popover, menu
    NetworkStatusItemController.swift  the separate network icon, its own menu
    MenuBarComposer.swift       shared icon+text composition for both status items
    BreakOverlayController.swift break windows per display, keyboard handling
    SettingsWindowController.swift
    Views/
      PopoverView.swift         the break dashboard
      NetworkPopoverView.swift  the network dashboard - speed rings, speed test, Wi-Fi list
      BreakView.swift           the break card
      SettingsView.swift        seven tabs
      Components.swift          rings, chips, bars, water dots
```

The whole app is one `AppModel` (an `ObservableObject`) driven by a one-second
timer, plus four thin AppKit controllers that render it - including two
independent status items, so the break and network features can each show up
(or disappear) in the menu bar on their own. **No third-party dependencies** -
the new features above are all built on system frameworks (EventKit,
UserNotifications, AppIntents, CoreWLAN/CoreLocation, and the same BSD network
counters `nettop` reads), never an external package.

---

## Troubleshooting

**No icon in the menu bar.** The bar was probably full - quit an item or widen
it. There's no Dock icon by design, so check it's running: `pgrep -x Downtime`.

**Reminders never fire.** Open the dashboard and look for a pause reason
("Outside your work hours", "You're away - timer on hold"). If "Don't interrupt
fullscreen apps" is on, try turning it off.

**"Open at login" won't stick.** Ad-hoc-signed builds sometimes get refused by
`SMAppService`; a LaunchAgent fallback covers it, and the toggle reports what
actually happened.

**Build warnings about main-actor isolation.** Expected. The package pins the
Swift 5 language mode; the warnings are AppKit's pre-concurrency annotations and
don't affect the build.

**Calendar-aware pausing says access is off.** Grant it in
System Settings → Privacy & Security → Calendars, then toggle the setting back
on - Downtime only re-asks when you flip the switch.

**Notification break style shows nothing.** Check System Settings →
Notifications → Downtime. Notifications also need the app to be properly
bundled and code-signed (which `build.sh` already does); running the raw
binary outside the `.app` won't work.

---

## Contributing

Issues and pull requests are welcome. The codebase is deliberately small and
dependency-free - please keep it that way.

Every push and pull request builds on macOS via GitHub Actions
(`.github/workflows/build.yml`) - a debug build, a universal release build,
and a full app bundle assembly, so a broken build can't land on `main`.
Pushing a `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which builds
the universal binary, zips it, and publishes it as a GitHub release
automatically.

If you find this useful, there's a **Buy me a coffee** link in
Settings → Support.

---

## License

See [LICENSE](LICENSE) if present; otherwise all rights reserved by the author.
