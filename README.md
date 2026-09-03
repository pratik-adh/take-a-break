# Take a Break

**A macOS app that's concerned about your health.**

It sits in your menu bar and looks after the three things a long day at a
computer quietly takes from you — your eyes, your back, and your hydration —
by telling you to stand up, drink water, and look away from the screen *before
your body has to tell you itself.*

It keeps a live countdown next to the clock. When a timer runs out it puts a
break card on screen: what to do, how long, and a ring counting the break down.
You can snooze it, skip it, or let it finish on its own.

```
menu bar:    👁 20m        ← next reminder, counting down
click:       dashboard — rings, toggles, water tracker, streak
right-click: break now · pause · settings · quit
```

**No Dock icon. No account. No network code. Nothing leaves your Mac.**

---

## What it's looking after

A full day at a screen is a slow accumulation of small strains. This app is
built around the three that are easiest to prevent and easiest to ignore:

| | The problem | What the app does |
|---|---|---|
| 👁 **Your eyes** | Screens cut your blink rate by about half, and hours of fixed-distance focus leaves eyes dry, tired and sore — the cluster usually called digital eye strain. | Nudges you every 20 minutes to look ~20 feet away for 20 seconds and blink — the optometrist's **20-20-20 rule**, built in as a one-click preset. |
| 🚶 **Your back and circulation** | Sitting still for hours stiffens hips and shoulders, loads your lower back, and is the part of desk work your body complains about years later. | Reminds you to stand, straighten, reach and actually walk a few steps — movement, not just a stretch in your chair. |
| 💧 **Your hydration** | Thirst usually shows up as tiredness and a headache first, so you reach for another coffee instead of water. | A gentle nudge to refill, plus a daily glass tracker so you can see whether you actually drank. |

None of this is medical advice — it's the ordinary, well-worn desk-health
guidance, made hard to forget.

---

## Why another reminder app

Most break reminders fail in one of two ways. Either they nag on a dumb wall
clock — firing while you're in a meeting, or thirty seconds after you sat back
down from lunch — or they're so easy to dismiss that you reflexively swat them
away without ever taking the break.

Take a Break tries to earn the interruption instead:

- **It only counts time you were actually at the screen.** Step away and the
  timers hold. Stay away long enough and they reset and you get credit — so
  coming back from lunch doesn't mean an instant reminder.
- **It knows when to stay quiet.** Optional work hours, optional fullscreen
  detection, and a pause button with real durations.
- **It tells you what to do, not just that time passed.** Each break names the
  action — stand and reach, drink a few mouthfuls, look 20 feet away — and the
  copy uses your real screen time, not a placeholder.
- **It keeps score, locally.** Breaks taken, skipped and snoozed, plus a streak,
  so the habit is visible without a dashboard in the cloud.

---

## The three reminders

Each runs on its own timer and can be turned off independently.

| Reminder | Default interval | Default break | What it asks |
|---|---|---|---|
| **Stand & Stretch** | every 1 hour | 3 min | stand up, roll your shoulders, walk a bit |
| **Drink Water** | every 45 min | 30 s | refill and actually drink |
| **Rest Your Eyes** | every 20 min | 20 s | look ~20 ft away and blink |

Intervals: 20 / 30 / 45 min · 1 / 1.5 / 2 / 3 / 4 / 5 hours.
Break lengths: 20 s / 30 s / 1 / 2 / 3 / 5 / 10 min.

There's a one-click **Apply the 20-20-20 rule** button in Settings → Reminders:
every 20 minutes, look 20 feet away, for 20 seconds — the optometrist's version
of the eye break.

When two reminders come due together, you get **one** card and the other is
marked as served — but only if the break is long enough to cover it, so nothing
reappears thirty seconds later.

---

## Feature tour

**Menu bar** — a live countdown to the next reminder, in monospaced digits so it
doesn't jitter as it ticks. Seconds optional, or hide the countdown entirely and
keep just the icon. When the dashboard is open and the item resizes underneath
it — a countdown collapsing to a bare paused icon — the popover re-centres on it
rather than being left stranded off-anchor.

**The dashboard** (left-click) — a ring counting down to whatever is next, a row
per reminder with its own progress ring and on/off switch, a water tracker,
Break now, today's stats, and a 7-day bar chart with your streak.

**Break screen** — three styles, from a small corner card to a full dim that
won't let you skip. Shows a countdown ring, what to do, an optional wellbeing
tip, and snooze/skip/done.

**Snooze** — default 10 minutes, capped at 3 per break by default so it can't
become a reflex. Other lengths available without opening Settings.

**Quiet by default when you're not there** — idle detection, screen lock and
display sleep all hold the timers; a long enough absence counts as a break.

**Work hours** — optional weekday + time window, overnight windows handled
correctly.

**Stats** — breaks taken / skipped / snoozed, break time, screen time and
glasses per day, kept for 120 days, with a streak counter.

**Custom wording** — rewrite any reminder's headline and message, with
`{duration}`, `{minutes}`, `{time}` and `{count}` placeholders filled in for
real.

**Light and dark** — the palette is defined as appearance-aware design tokens,
with a darker, more saturated set of brand hues for light mode so nothing reads
as washed out on a white background.

📖 **[Full feature reference → FEATURES.md](FEATURES.md)** — every setting,
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
open "dist/Take a Break.app"
```

The first launch puts a cup icon in your menu bar and nothing in the Dock —
that's deliberate (`LSUIElement`). Quit from the menu bar item.

Everything is Swift Package Manager, so `swift build -c release` on its own works
too; `build.sh` only adds the `.app` wrapper, the icon, and an ad-hoc signature.

> **Unsigned build note:** this is ad-hoc signed, not notarized. macOS may warn
> on first launch — right-click the app → Open, or allow it in
> System Settings → Privacy & Security.

---

## Privacy

There is no network code in this app at all. No analytics, no accounts, no
telemetry, no update check.

- Settings live in your user defaults under `com.takeabreak.mac`.
- History lives in `~/Library/Application Support/TakeABreak/stats.json`.
- Settings → Stats has an **Erase all history** button.

It needs **no special permissions** — idle detection uses
`CGEventSource.secondsSinceLastEventType`, which requires no Accessibility grant.

---

## Source layout

```
Package.swift
build.sh                        compile → "Take a Break.app" (icon, ad-hoc signature)
Resources/
  Info.plist                    LSUIElement, bundle id com.takeabreak.mac
  icon_1024.png                 source art; build.sh turns it into AppIcon.icns
Sources/TakeABreak/
  main.swift                    NSApplication bootstrap, accessory policy
  AppDelegate.swift             wires the model to the three controllers
  Models/
    ReminderKind.swift          the three reminders: copy, colours, tips
    Settings.swift              preferences, presets, forgiving decode
    Stats.swift                 daily history, streaks, JSON store
  Core/
    AppModel.swift              the engine: tick loop, breaks, snooze, pause
    SystemMonitor.swift         input idle time, screen lock/sleep, fullscreen
    DesignTokens.swift          appearance-aware colour tokens
    Format.swift                durations, countdowns, message placeholders
    SoundPlayer.swift           system sounds
    LaunchAtLogin.swift         SMAppService + LaunchAgent fallback
  UI/
    StatusItemController.swift  menu bar icon, countdown, popover, menu
    BreakOverlayController.swift break windows per display, keyboard handling
    SettingsWindowController.swift
    Views/
      PopoverView.swift         the dashboard
      BreakView.swift           the break card
      SettingsView.swift        six tabs
      Components.swift          rings, chips, bars, water dots
```

The whole app is one `AppModel` (an `ObservableObject`) driven by a one-second
timer, plus three thin AppKit controllers that render it. **No third-party
dependencies.**

---

## Troubleshooting

**No icon in the menu bar.** The bar was probably full — quit an item or widen
it. There's no Dock icon by design, so check it's running: `pgrep -x TakeABreak`.

**Reminders never fire.** Open the dashboard and look for a pause reason
("Outside your work hours", "You're away — timer on hold"). If "Don't interrupt
fullscreen apps" is on, try turning it off.

**"Open at login" won't stick.** Ad-hoc-signed builds sometimes get refused by
`SMAppService`; a LaunchAgent fallback covers it, and the toggle reports what
actually happened.

**Build warnings about main-actor isolation.** Expected. The package pins the
Swift 5 language mode; the warnings are AppKit's pre-concurrency annotations and
don't affect the build.

---

## Contributing

Issues and pull requests are welcome. The codebase is deliberately small and
dependency-free — please keep it that way.

If you find this useful, there's a **Buy me a coffee** link in
Settings → Support.

---

## License

See [LICENSE](LICENSE) if present; otherwise all rights reserved by the author.
