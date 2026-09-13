# Downtime - full feature reference

Downtime is a macOS menu-bar app that's concerned about your health: it
looks after your eyes, your back and your hydration through a working day at the
screen. It also knows how to stay out of your way - holding reminders during a
meeting or a fullscreen app - and, optionally, tracks how much data you've used.
This document covers every feature, every setting, every default, and the
behaviour behind each one. For the overview and install instructions, see
[README.md](README.md).

- [Menu bar](#menu-bar)
- [The dashboard](#the-dashboard-left-click)
- [Reminders](#reminders)
- [Break screens](#break-screens)
- [Snooze, skip and done](#snooze-skip-and-done)
- [Presence: idle, lock and sleep](#presence-idle-lock-and-sleep)
- [Work hours](#work-hours)
- [Fullscreen apps](#fullscreen-apps)
- [Calendar-aware pausing](#calendar-aware-pausing)
- [Pausing and resuming](#pausing-and-resuming)
- [Water tracking](#water-tracking)
- [Stats and streaks](#stats-and-streaks)
- [Network usage](#network-usage)
- [Custom wording](#custom-wording)
- [Sound](#sound)
- [Open at login](#open-at-login)
- [Shortcuts (App Intents)](#shortcuts-app-intents)
- [Settings backup](#settings-backup)
- [Appearance and design tokens](#appearance-and-design-tokens)
- [Settings reference](#settings-reference)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Where your data lives](#where-your-data-lives)

---

## Menu bar

The app runs as an `LSUIElement` accessory: **menu bar only, no Dock icon, no
main window.**

The status item shows the icon of whichever reminder is next, plus a live
countdown to it:

| State             | Icon                       | Text                                           |
| ----------------- | -------------------------- | ---------------------------------------------- |
| Counting down     | the next reminder's symbol | `20m`, `1h04`, or `19:58` with seconds         |
| Break on screen   | that break's symbol        | the break's own countdown, always with seconds |
| Paused            | the pause reason's symbol  | _(none)_                                       |
| All reminders off | `bell.slash`               | _(none)_                                       |

**Countdown format** - under an hour it reads `45m`; over an hour, `1h04`. Turn
on seconds and it becomes `44:59` / `1:04:32`. Both are rendered in a
monospaced-digit font so the width doesn't jitter as the numbers tick.

**Network usage has its own, separate icon** - not part of this one. See
[Network usage](#network-usage) below.

**Hover tooltip** lists every enabled reminder and its remaining time at once,
or the current pause reason.

**Stable position.** The status item's own width changes as its content does -
a countdown collapsing to a bare paused icon is a ~40pt difference - which
slides it and everything left of it sideways. When the dashboard is open, it
tracks the button's real on-screen position and re-centres itself, so pausing or
resuming never leaves the popover stranded off-anchor.

**Click behaviour:**

- **Left-click** - opens the dashboard popover.
- **Right-click** (or Control-click) - a native menu: current status, Take a
  break now, Restart all timers, Pause reminders ▸, Settings… (`⌘,`),
  Quit (`⌘Q`).

---

## The dashboard (left-click)

A 332pt-wide card, sized to its contents on every open:

1. **Header** - app name, a pause/resume menu, and a Settings button.
2. **Hero ring** - a large progress ring counting down to the next reminder,
   with its symbol and label ("until eyes"). While paused it reads `paused` and
   the ring greys out. Below it: _"At the screen for 1h 12m"_ - your longest
   current unbroken stretch - or the pause reason if reminders are on hold.
3. **Reminder rows** - one per reminder: progress ring, name, interval,
   remaining time, and a switch to toggle it. Toggling takes effect instantly.
4. **Water tracker** - a row of droplets with `−` / `+`.
5. **Break now** + **Restart all timers**.
6. **Today's stats** - breaks taken, day streak, screen time.
7. **7-day chart** - a bar per day against your goal, today in bold.
8. **Footer** - Settings (gear), Pause/Resume, Quit.

The footer's **Pause** is a plain toggle: one tap holds reminders until you press
Resume. The timed choices ("for 20 minutes", "until tomorrow") live in the header
menu. When reminders are held by something you can't lift - you're away, or a
fullscreen app is up - the button is disabled rather than pretending to work.

---

## Reminders

Three independent reminders, each with its own timer, interval, break length,
colour, symbol, copy and tips.

|                  | Stand & Stretch                                           | Drink Water                                        | Rest Your Eyes                                               |
| ---------------- | --------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------ |
| Looks after      | back, hips, circulation                                   | hydration, energy levels                           | eye strain, dryness                                          |
| Default interval | 60 min                                                    | 45 min                                             | 20 min                                                       |
| Default break    | 3 min                                                     | 30 s                                               | 20 s                                                         |
| Symbol           | `figure.walk`                                             | `drop.fill`                                        | `eye.fill`                                                   |
| Instruction      | "Stand, straighten your back, and reach for the ceiling." | "Drink at least a few mouthfuls - not just a sip." | "Look at something about 20 feet (6 m) away for 20 seconds." |

**Interval choices:** 20, 30, 45 min, 1 h, 1.5 h, 2 h, 3 h, 4 h, 5 h.
**Break-length choices:** 20 s, 30 s, 1, 2, 3, 5, 10 min.

**Changing an interval restarts that timer** from zero, as does switching a
reminder back on - so a change takes effect predictably instead of firing
immediately because the old counter was already past the new interval.

### When two come due at once

You get **one** card, not a queue. The reminder with the **longest break** owns
the card, because a long break also serves the short ones. The others ride along
as _"also due"_ chips.

A reminder is only folded in if the owning break is **at least as long** as its
own - so a 20-second eye break never silently counts as your 3-minute stretch.
Anything that was cut short is pushed out rather than fired again immediately.

### The 20-20-20 preset

Settings → Reminders → **Apply the 20-20-20 rule** sets the eye reminder to
every 20 minutes / 20 second break and switches it on.

---

## Break screens

| Style                   | Behaviour                                                                                                                                      |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| **Gentle**              | Small card in the top-right corner. Never steals focus, never covers your work.                                                                |
| **Focused** _(default)_ | Frosted dim over the whole screen with the card in the middle. Skippable.                                                                      |
| **Strict**              | Same, but Okay and Esc are locked out until the timer reaches zero.                                                                            |
| **Notification**        | No window at all - a native macOS notification with Done / Snooze / Skip actions. Asks for notification permission the first time you pick it. |

The card shows: the reminder name, a countdown ring, the headline, the message
(with your real screen time substituted in), the instruction, any "also due"
chips, an optional wellbeing tip, and the buttons.

**Multiple displays** - Focused and Strict dim every display (optional, on by
default) and put the card on your active screen. The overlay windows join all
Spaces and sit at screen-saver level.

**Strict mode** only holds you for _automatic_ breaks - a break you asked for
yourself with "Break now" is always skippable, so the strict setting can't lock
you out of a break you opted into.

**When the timer hits zero** the card switches to "Break complete", optionally
chimes, and by default closes itself.

The **Notification** style has no window and no keyboard shortcuts - use the
notification's own Done / Snooze / Skip buttons instead. Everything else
(counting down, "also due" folding, stats) works exactly the same underneath;
only how the break is announced changes.

---

## Snooze, skip and done

**Snooze** - default 10 minutes. Choices: 3, 5, 10, 15, 20, 30 min. A chevron
next to the button offers the other lengths without opening Settings.

**Snooze cap** - default 3 per break; also 1, 2, 5, or Unlimited. Once the cap is
hit the button disappears for that break. The card shows how many you have left.

Snoozing pushes the reminder out by the full snooze length even if that's longer
than the reminder's own interval, and takes any "also due" reminders with it.

**Done / Okay** - counts as a break taken if the timer finished _or_ you gave it
at least half the break. Otherwise it counts as skipped, honestly.

**Skip** - always counts as skipped.

Finishing a **water** break (or one that served water) logs a glass
automatically.

After any break there's a **45-second grace period** before another can fire,
so finishing one break never immediately triggers the next.

---

## Presence: idle, lock and sleep

Idle time comes from `CGEventSource.secondsSinceLastEventType` across keyboard,
mouse, drag and scroll events. **No Accessibility permission required.**

Two thresholds:

| Setting                              | Default | Choices                         | Meaning                                                      |
| ------------------------------------ | ------- | ------------------------------- | ------------------------------------------------------------ |
| **Hold the timer after**             | 90 s    | 30 s, 1 min, 90 s, 3 min, 5 min | Stop counting screen time after this much inactivity         |
| **Count time away as a break after** | 5 min   | 2, 3, 5, 10, 15, 30 min         | Being away this long _resets_ the timers and credits a break |

So: a short pause holds the clock; a real absence counts as the break it was.
Coming back from lunch doesn't mean an instant reminder.

**Screen lock, display sleep and system sleep** count the same way, via
`NSWorkspace` and the `com.apple.screenIsLocked` notifications - and have to
last just as long as walking away does to earn the credit.

After an away-credit there's a 30-second grace period before anything can fire.

---

## Work hours

Off by default. Pick weekdays and a start/end time, and reminders go quiet
outside them.

- **Overnight windows work** - e.g. 21:00 → 03:00 correctly spans midnight and
  attributes the early-morning hours to the previous day's weekday selection.
- **Start == end means "all day"** on the selected weekdays, not "never".
- Deselecting every weekday is prevented - the last one stays on.

If you hit **Resume** while outside your work hours, that's read as "remind me
anyway": the schedule is overridden until it next comes back around on its own,
rather than re-pausing you a second later.

---

## Fullscreen apps

Off by default. When on, reminders are suppressed while another app owns a
window exactly the size of a display - presentations, films, games.

It's a heuristic (`CGWindowListCopyWindowInfo`, throttled to once every five
seconds), which is exactly why it ships off. If reminders start going missing,
turn it off.

---

## Calendar-aware pausing

Off by default. When on, reminders hold automatically while an event on your
calendar is happening right now - no schedule to configure, it just checks the
current moment.

- Reads calendar events via **EventKit**, polling once every 30 seconds for
  anything active right now (a 2-second window around "now"). It never reads
  your calendar in bulk, never stores an event, and never sends anything
  anywhere - the only thing kept is a live yes/no plus the current event's
  title, shown in Settings so you can see why reminders are quiet.
- **Ignore all-day events** is on by default, so a birthday or a holiday
  doesn't hold your reminders for the whole day.
- Cancelled events are ignored.
- Turning this on is the moment Downtime actually asks macOS for Calendar
  access - it's the one feature in the app that needs a system permission. If
  you decline (or later revoke it in System Settings → Privacy & Security →
  Calendars), Settings → Schedule explains that plainly instead of silently
  doing nothing.
- Like fullscreen detection and being away, this is a fact about the world
  rather than something you chose - the Resume button doesn't appear for it;
  it clears itself when the meeting ends.

---

## Pausing and resuming

From the dashboard header menu or the right-click menu:

- Pause for **20 minutes**, **1 hour**, or **2 hours**
- Pause **until tomorrow** (resumes 5 a.m.)
- Pause **until I turn it back on**

The footer's **Quit Break Mode** button is the simple version of the last one

- named that deliberately, alongside the network icon's own "Quit Network
  Mode," so it's clear each stops _that_ feature only. Neither menu offers to
  quit the other one, and only this icon's menu has the true "Quit Downtime"
  that ends the app entirely.

Pausing closes any break already on screen cleanly, so a reminder is never lost
mid-break. A timed pause expires by itself.

**While manually paused, the dashboard collapses** the reminder list, water
tracker, actions and stats into a single "Reminders are paused" notice with
its own Resume Break Mode button - the hero ring stays (it already shows the
paused state clearly) but the rest has nothing fresh to show. This only
happens for a real pause; being away, in a fullscreen app, in a meeting, or
outside work hours are transient world-states, and the dashboard stays fully
visible during those since it's still useful to glance at.

**Honest affordances.** The app distinguishes holds you set from facts about the
world. Manual pauses and the work-hours schedule are yours to lift, so Resume
appears and works. Being away or in a fullscreen app clears itself when the
situation does - there, the menu shows the reason instead of a Resume button
that couldn't do anything.

---

## Water tracking

A row of droplets in the dashboard; `+` and `−` to adjust. Finishing a water
break logs one automatically. The daily goal is configurable (1–16, default 8).
Going over the goal shows a `+n` badge rather than hiding the overflow.

---

## Stats and streaks

Recorded per day: **breaks taken**, **breaks skipped**, **snoozes**, **break
seconds**, **screen seconds**, **glasses**, plus (see below) **per-reminder
breaks taken** and **network bytes up/down**.

- **7-day bar chart** in the dashboard and in Settings → Stats.
- **Overall streak** - consecutive days that met your daily break goal (1–30,
  default 8). Today only counts once you've _hit_ the goal, so the streak
  doesn't read as broken every morning before you've earned it.
- **Per-reminder streaks** - Stand & Stretch, Drink Water and Rest Your Eyes
  each keep their own streak against their own daily goal (Settings → General
  → _Per-reminder goals_, 1–30 each, defaults 5 / 6 / 8). A day away from your
  desk long enough to be credited as a break counts toward every enabled
  reminder's streak, same as it does for the overall one.
- **This week vs. last week** - Settings → Stats shows breaks taken and
  compliance for the last 7 days against the 7 before that, so a good or bad
  week has something to compare against besides a flat number.
- History is kept for **120 days**, saved to disk every 30 seconds and on quit.
- Settings → Stats → **Erase all history**, with a confirmation.

---

## Network usage

Optional, **on by default**, and deliberately kept **separate from the break
reminders** - its own icon, its own pause switch, its own settings - so the
two features stay legible at a glance instead of blurring into one thing.

**How it's read** - once a second, alongside the reminder tick, the app reads
the same cumulative interface byte counters Activity Monitor's Network tab and
tools like `nettop`/`netstat -ib` read (`sysctl(NET_RT_IFLIST2)`), across every
interface except loopback. This needs **no permission prompt** and involves
**no network requests of any kind** - it's a purely local read of counters the
kernel already keeps. A negative delta (Wi-Fi toggled, VPN reconnected) is
skipped rather than counted as a spike. (The one exception to "no network
requests" anywhere in this feature is the on-demand speed test below, which
only ever runs when you tap its button.)

### Its own menu bar icon

A second, independent status item - a network glyph, optionally with a
**total-usage** readout next to it (Settings → Network → _Menu bar_ → pick
Today's / This week's / This month's usage). This is deliberately a total,
not a live rate: a number that ticks every second is hard to read at a
glance and stops meaning anything the moment you look away. Live up/down
_speed_ lives one click away instead - see the popover below. The icon and
the break icon are rendered the same way - the glyph composed as a single
attributed string with the icon inlined and baseline-corrected against the
text, rather than `NSButton`'s separate image+title layout - so the two sit
visually aligned rather than looking like two different conventions.
Right-click the icon for today's totals, **Quit Network Mode** (or **Resume
Network Mode**), and Settings.

**Pausing is independent of the break reminders, and it's called "Quit
Network Mode" on purpose.** Turning it off - from Settings, the icon's own
right-click menu, or the popover's footer - stops tracking; the break
reminder icon and its own "Quit Break Mode" are completely unaffected, and
vice versa. Neither menu offers to quit the _other_ feature, and only the
break icon's menu has the true "Quit Downtime" that ends the app.

**The paused network icon shows a pause glyph rather than vanishing** - the
same convention the break icon already uses - so it (and any popover open at
the time) stays anchored to something real instead of disappearing out from
under it. The one exception: if **both** features happen to be paused at
once, the network icon steps aside and disappears, since the break icon is
already showing a pause glyph of its own - two side by side would just be a
redundant second copy of the same signal. If a popover was open when that
happened, it closes automatically rather than being left floating with
nothing to point at.

### Clicking the network icon: its own popover

Left-click opens a popover shaped like the break dashboard - header (icon,
title, pause button, gear), a live hero, a speed test, a Wi-Fi usage list,
and a footer (gear, Quit Network Mode). Right-click gives the same options
as a plain menu.

**The hero shows both a rate and a total, deliberately, and leads with the
total.** Each ring's big number is today's actual usage by default - a live
rate only means something the instant you're looking at it, a total still
means something a minute later - with the live ↓/↑ speed underneath instead.
A segmented control (**Today's Usage** / **Live Speed**) above the rings
swaps which one is primary; nothing is hidden either way, just which number
is large. Download and upload are tracked and shown as genuinely separate
numbers throughout (verified: the counters are read from distinct kernel
fields, `ifi_ibytes`/`ifi_obytes`, and kept apart end to end, so the two are
never the same figure by coincidence of a bug). The speed test's own numbers
are unrelated to this and unaffected by it.

**The ring's fill means something different in each mode.** In Live Speed
mode it's the same illustrative soft cap as before (5 MB/s = full - ordinary
browsing sits mid-ring). In Today's Usage mode it fills toward a concrete MB
target instead: your own daily data budget (Settings → Network → Daily data
budget) if you've set one, since that's already the one number in this app
meant to represent "a day's worth," or a plain 1 GB milestone if you haven't.

**While paused, the popover collapses to a single notice** ("Network
tracking is paused" + a Resume Network Mode button) instead of a wall of
stale, dimmed sections - there's no live speed, no fresh usage, and nothing
new for the Wi-Fi list to show while tracking is off, so showing all of that
anyway would just be noise.

### Speed test

The passive tracking above measures _ambient_ usage - whatever's actually
moving right now, which sits near zero between page loads. It cannot tell you
what your connection is _capable of_. For that, the popover has a **Test
Speed** button (a speedometer icon) that runs a real speed test: latency
(ping), download, and upload, each shown as its own stage rather than one
long spinner, finishing in a row of three result chips (↓ Mbps, ↑ Mbps, ping
ms) with a **Test Again** button styled like a real button, not a plain link.

This is the **one place in the entire app that makes an actual network
request** - everything else here is a local read, verified by checking the
running app's actual open network connections with nothing clicked: none.
It uses Cloudflare's public speed-test endpoints (`speed.cloudflare.com`, the
same infrastructure behind their own public speed test page and various
third-party tools): a small request for latency, a ~25 MB download, and a
~10 MB upload, all discarded server-side, nothing personal attached beyond
what any HTTPS request already carries. It never runs on its own - only when
you tap the button - and a **Cancel** button is available mid-test.

**If the Mac has no usable network path at all**, checked live via
`NWPathMonitor` (a local, permission-free system read - not part of the
speed test itself), the button is replaced with a plain "No network
connection available" notice instead of a button that's just going to fail;
the same check distinguishes a genuine outage from an ordinary failed test
(server hiccup, timeout), which still gets the regular Retry button.

### What you see (Settings → Network, top to bottom)

1. **Network tracking** - the master on/off (same switch as pausing from the icon).
2. **Menu bar** - icon on/off, which period's total to show (day/week/month), live preview.
3. **Display** - show upload/download as separate rows or one combined figure,
   applied consistently to every figure below.
4. **Daily data budget** - see below.
5. **Today**, **This week**, **This month** - each as separate ↓/↑ rows or one
   combined total, per the Display setting above.
6. **By Wi-Fi network** - opt-in usage breakdown by network name (see below).
7. **All-time total** - everything still in history (up to 120 days), always last.

**Daily data budget** - off by default. Pick a threshold (500 MB up to 20 GB)
and crossing it sends **one** nudge notification for the day. This is
explicitly a nudge, not an enforced limit: actually blocking or throttling
traffic needs a Network Extension (its own Apple Developer entitlement and
provisioning profile) or a root-privileged helper, neither of which fits an
app that ships as a single unprivileged, ad-hoc-signed binary. If that's ever
worth the added complexity and signing requirements, it would be a separate,
bigger effort.

**By Wi-Fi network** - off by default. Labels usage by the Wi-Fi network you
were connected to at the time (wired connections and unreadable networks are
grouped as "Other network," shown with a distinct cable icon rather than
wifi bars it hasn't earned). The list is sorted largest-first, and whichever
network you're on right now carries a green **"now"** badge - live, updated
every tick, not just when the list happens to redraw. In the popover, every
row (current or not - clicking behaves identically either way) opens
**macOS's own Wi-Fi settings** - not this app's - the same pane Control
Center's own "Wi-Fi Settings…" link opens, in case you actually want to do
something about the network in question (forget it, check its details, etc.)
rather than just read a total.

Reading the _current_ Wi-Fi name requires **Location Services
authorization** - a macOS-wide restriction on SSID access since Catalina,
because a network name can reveal where you are. Turning this on is the
moment the app asks for that permission; declining (or revoking it later in
System Settings → Privacy & Security → Location Services) shows a plain
explanation in Settings rather than silently doing nothing. Nothing about
this ever leaves your Mac - the name only labels your own local usage
history.

---

## Custom wording

Settings → Reminders → _Custom wording_ rewrites any reminder's headline and
message. Placeholders are substituted for real:

| Token        | Becomes                                               |
| ------------ | ----------------------------------------------------- |
| `{duration}` | `1 hour 5 minutes` - your actual unbroken screen time |
| `{minutes}`  | `65`                                                  |
| `{time}`     | `4:32 PM`, in your locale                             |
| `{count}`    | which break of the day this is                        |

Leave a field empty to fall back to the default copy.

**Wellbeing tips** - five per reminder, one picked at random per break. Can be
switched off.

---

## Sound

A system sound when a break starts, and optionally a chime when it finishes.

**Choices:** Silent, Ping _(default)_, Glass, Tink, Pop, Purr, Submarine,
Bottle, Blow, Hero, Sosumi. Volume slider with a **Test** button. Choosing
Silent disables the chime and volume controls too.

---

## Open at login

Settings → General → **Open Downtime at login**.

Registers with `SMAppService`. If macOS refuses - which unsigned local builds
sometimes do - it falls back to a LaunchAgent at
`~/Library/LaunchAgents/com.downtime.mac.launcher.plist`. Either way the
toggle reports what actually happened rather than silently failing.

---

## Shortcuts (App Intents)

Four actions are exposed to Shortcuts and Siri, built with **App Intents** -
no separate extension, no entitlement, just Swift in the main app target:

| Shortcut                 | Does                                           |
| ------------------------ | ---------------------------------------------- |
| **Take a Break Now**     | Starts whichever reminder is next up           |
| **Pause Reminders**      | Pauses for a number of minutes (parameterized) |
| **Resume Reminders**     | Resumes reminders                              |
| **Log a Glass of Water** | Adds one glass to today's count                |

Build a Shortcut around these the same way as any other app's actions - e.g.
"When my Focus turns on, Pause Reminders for 60 minutes."

---

## Settings backup

Settings → General → **Export Settings…** / **Import Settings…** saves your
whole configuration (reminders, break style, schedule, calendar/network
settings, per-reminder goals - everything except your stats history) to a
JSON file and loads it back. Useful for moving to another Mac or keeping a
known-good configuration on hand. Import uses the same forgiving decode as
every other settings load, so a file from an older or newer build still works.

---

## Appearance and design tokens

The palette is defined as **appearance-aware tokens** that resolve differently in
light and dark, rather than one value expected to work against both.

The three brand hues keep their hue angle but get a darker, more saturated
variant for light mode, because a colour tuned to glow on a near-black window
reads as pale on white:

|               | Light                   | Dark                    |
| ------------- | ----------------------- | ----------------------- |
| Stand (green) | `rgb(0.12, 0.58, 0.41)` | `rgb(0.24, 0.80, 0.60)` |
| Water (blue)  | `rgb(0.13, 0.42, 0.69)` | `rgb(0.26, 0.62, 0.96)` |
| Eyes (purple) | `rgb(0.43, 0.31, 0.68)` | `rgb(0.64, 0.49, 0.95)` |

Surface tokens work the same way - card fills, borders and the popover's own
background are each specified per appearance, so card-against-background
contrast lands in the same place in both themes (≈1.20 light, ≈1.16 dark)
instead of light trailing badly behind.

Everything follows the system setting automatically; there is no theme switch to
set.

---

## Settings reference

Seven tabs.

### Reminders

Per reminder: on/off, interval, break length, custom headline, custom message.
Plus the 20-20-20 preset button.

### Break Screen

Style (Gentle / Focused / Strict / Notification) · Dim other displays ·
Snooze length · Snoozes per break · Close automatically when the timer ends ·
Show a wellbeing tip · Preview a break now.

### Schedule

Only remind me during work hours · From/to times · Weekday picker · live
"Right now" status · Hold the timer after · Count time away as a break after ·
Don't interrupt fullscreen apps · **Calendar: pause during meetings, ignore
all-day events, access status** · current idle seconds · Resume now.

### General

Open at login · Show the countdown in the menu bar · Include seconds ·
Reminder sound, volume, Test · Chime when a break finishes · Breaks per day
goal · Glasses per day goal · **per-reminder daily goals** ·
**Export/Import Settings** · About · Restore all defaults.

### Stats

Today's chips (taken / skipped / snoozes / glasses) · screen time · break time ·
7-day chart · overall streak · **this week vs. last week** ·
**per-reminder streaks** · breaks this week · Erase all history.

### Network

Its own tab for its own icon and feature, kept separate from reminders:
tracking on/off (doubles as pause/resume) · menu bar icon + which period's
total it shows · combined-vs-separate display · daily data budget · today's /
this week's / this month's totals · **speed test** (latency, download, upload)
· by-Wi-Fi-network breakdown (opt-in, needs Location Services) · all-time
total, last.

### Support

Buy me a coffee · feedback note.

**Settings are saved on every change** and decoded forgivingly: every key falls
back to its default and out-of-range values snap to the nearest valid option, so
a settings file from an older or newer build still loads instead of being thrown
away.

---

## Keyboard shortcuts

**While a break is showing:**

| Key                | Action          |
| ------------------ | --------------- |
| `return` / `space` | Okay / I'm done |
| `S`                | Snooze          |
| `esc`              | Skip / dismiss  |

In Strict mode these are inert until the break finishes. Keys are only captured
when the break window itself is focused, so typing in Settings during a break
still works normally.

**From the menu bar menu:** `⌘,` Settings · `⌘Q` Quit.

---

## Where your data lives

| What                           | Where                                                                                                                      |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------- |
| Settings                       | user defaults, `com.downtime.mac`, key `downtime.settings.v1`                                                              |
| History (incl. network totals) | `~/Library/Application Support/Downtime/stats.json`                                                                        |
| Login item fallback            | `~/Library/LaunchAgents/com.downtime.mac.launcher.plist`                                                                   |
| Calendar events                | never stored - checked live via EventKit, only a yes/no and the current event's title are kept in memory                   |
| Notifications                  | delivered locally via `UNUserNotificationCenter`; nothing is sent to a server                                              |
| Wi-Fi network names (opt-in)   | stored only as usage totals in `stats.json` above, keyed by network name - never the SSID list itself, never sent anywhere |
| Speed test                     | not stored at all - the result lives in the popover until you close it or run another test                                 |

No analytics, no accounts, no update check. The **speed test is the sole
exception** to "no outbound network requests" - and only while you're actively
running it. Nothing else leaves your Mac.
