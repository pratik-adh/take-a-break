import AppKit
import Foundation
import SwiftUI

/// The app's three brand hues, picked to read clearly against *both*
/// backgrounds: a darker, more saturated shade for light windows (the same
/// RGB values read as pale/washed out once the background turns white), the
/// original brighter shade for dark ones.
private func adaptiveTint(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
    adaptiveColor(
        light: NSColor(red: light.0, green: light.1, blue: light.2, alpha: 1),
        dark: NSColor(red: dark.0, green: dark.1, blue: dark.2, alpha: 1)
    )
}

/// The three things Downtime nags you about.
enum ReminderKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case stand
    case water
    case eyes

    var id: String { rawValue }

    /// Higher wins when two reminders come due in the same second.
    var priority: Int {
        switch self {
        case .stand: return 3
        case .water: return 2
        case .eyes: return 1
        }
    }

    var title: String {
        switch self {
        case .stand: return "Stand & Stretch"
        case .water: return "Drink Water"
        case .eyes: return "Rest Your Eyes"
        }
    }

    var shortTitle: String {
        switch self {
        case .stand: return "Stretch"
        case .water: return "Water"
        case .eyes: return "Eyes"
        }
    }

    var symbolName: String {
        switch self {
        case .stand: return "figure.walk"
        case .water: return "drop.fill"
        case .eyes: return "eye.fill"
        }
    }

    var tint: Color {
        switch self {
        case .stand: return Self.standTint
        case .water: return Self.waterTint
        case .eyes:  return Self.eyesTint
        }
    }

    private static let standTint = adaptiveTint(light: (0.12, 0.58, 0.41), dark: (0.24, 0.80, 0.60))
    private static let waterTint = adaptiveTint(light: (0.13, 0.42, 0.69), dark: (0.26, 0.62, 0.96))
    private static let eyesTint  = adaptiveTint(light: (0.43, 0.31, 0.68), dark: (0.64, 0.49, 0.95))

    /// Default headline shown on the break screen.
    var defaultHeadline: String {
        switch self {
        case .stand: return "Time to stand up"
        case .water: return "Time for a glass of water"
        case .eyes:  return "Give your eyes a rest"
        }
    }

    /// Default body copy. `{duration}` is replaced with the real screen time,
    /// so unlike some reminder apps you never see a raw placeholder.
    var defaultMessage: String {
        switch self {
        case .stand:
            return "You've been at the screen for {duration}. Stand up, roll your shoulders, and walk a few steps."
        case .water:
            return "You've been at the screen for {duration}. Refill your glass and take a few sips."
        case .eyes:
            return "You've been at the screen for {duration}. Look at something far away and blink slowly."
        }
    }

    var instruction: String? {
        switch self {
        case .stand: return "Stand, straighten your back, and reach for the ceiling."
        case .water: return "Drink at least a few mouthfuls - not just a sip."
        case .eyes:  return "Look at something about 20 feet (6 m) away for 20 seconds."
        }
    }

    var tips: [String] {
        switch self {
        case .stand:
            return [
                "Roll your shoulders backwards ten times, slowly.",
                "Stand and tuck your chin to your chest to release your neck.",
                "Walk to the window and back - momentum beats stretching.",
                "Open your chest: clasp your hands behind your back and lift.",
                "Do five slow calf raises while you wait for the kettle."
            ]
        case .water:
            return [
                "Cold water wakes you up more than another coffee.",
                "Keep the glass in sight - you drink what you can see.",
                "Thirst usually shows up as tiredness first.",
                "A pinch of salt or lemon makes water easier to finish.",
                "Fill the glass now, even if you drink it in five minutes."
            ]
        case .eyes:
            return [
                "20-20-20: every 20 minutes, look 20 feet away for 20 seconds.",
                "Blink hard ten times - screens cut your blink rate in half.",
                "Cup your palms over closed eyes and let them rest in the dark.",
                "Trace a slow figure-eight with your gaze to loosen the muscles.",
                "Dry eyes? Lower your screen slightly below eye level."
            ]
        }
    }
}

enum BreakStyle: String, Codable, CaseIterable, Identifiable {
    /// A small card in the corner. Never steals focus.
    case gentle
    /// Dims the screen with a centered card. Skippable.
    case focused
    /// Dims the screen and won't let you dismiss until the break is over.
    case strict
    /// A system notification instead of any on-screen window.
    case notification

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gentle:       return "Gentle"
        case .focused:      return "Focused"
        case .strict:       return "Strict"
        case .notification: return "Notification"
        }
    }

    var detail: String {
        switch self {
        case .gentle:       return "A small card in the corner of the screen. Never takes focus."
        case .focused:      return "Dims the whole screen with a card in the middle. Skippable."
        case .strict:       return "Dims the screen and keeps the card up until the break is finished."
        case .notification: return "Sends a macOS notification instead of taking over the screen. Snooze or mark it done right from the notification."
        }
    }

    var symbolName: String {
        switch self {
        case .gentle:       return "bell.badge"
        case .focused:      return "rectangle.inset.filled"
        case .strict:       return "lock.fill"
        case .notification: return "bell.badge.fill"
        }
    }
}
