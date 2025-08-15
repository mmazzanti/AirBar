//
//  AirBarApp.swift
//  AirBar
//
//  Created by Matteo Mazzanti on 15.08.2025.
//

import SwiftUI

@main
struct AirStatusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
