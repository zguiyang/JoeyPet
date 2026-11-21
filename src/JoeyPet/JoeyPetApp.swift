//
//  JoeyPetApp.swift
//  JoeyPet
//

import SwiftUI

@main
struct JoeyPetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
