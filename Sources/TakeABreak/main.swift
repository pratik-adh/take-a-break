import AppKit

// Take a Break runs as a menu bar accessory: no Dock icon, no main window.
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
