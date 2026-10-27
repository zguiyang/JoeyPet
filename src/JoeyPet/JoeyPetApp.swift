//
//  JoeyPetApp.swift
//  JoeyPet
//

import Foundation
import SwiftUI

@main
struct JoeyPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // JoeyPet's windows are AppKit-owned (`AppDelegate`/`MainWindowController`;
        // see AGENTS.md). This scene exists only to keep SwiftUI's app-menu plumbing
        // (About/Hide/Quit, Edit, Window, Help). Its window must never be opened: the
        // real Settings page is an in-window page, not a separate settings window.
        Settings {
            EmptyView()
        }
        .commands {
            // Replace the system-provided Settings item (which would open the empty
            // scene window) with the app's existing in-window Settings page. The
            // command only posts the intent; AppDelegate owns the main window and
            // routes it to the same presentation path as the status-bar 设置… item.
            CommandGroup(replacing: .appSettings) {
                Button("设置…") {
                    NotificationCenter.default.post(name: .joeyPetOpenSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
