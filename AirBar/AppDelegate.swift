//
//  AppDelegate.swift
//  AirBar
//
//  Created by Matteo Mazzanti on 15.08.2025.
//

import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var viewModel: GraphViewModel!
    var cancellables = Set<AnyCancellable>()
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load saved settings
        let savedToken = UserDefaults.standard.string(forKey: "apiToken") ?? ""
        let savedLocationID = UserDefaults.standard.string(forKey: "locationID") ?? ""
        viewModel = GraphViewModel(apiToken: savedToken, locationID: savedLocationID)
        
        // Setup status bar (fixed width so it won’t vanish)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "⏳"  // temporary placeholder
            button.action = #selector(togglePopover(_:))
        }
        
        // Setup popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 250)
        popover.contentViewController = NSHostingController(rootView: GraphView(viewModel: viewModel))
        
        // Add global click monitor to close popover when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return }
            if self.popover.isShown {
                self.popover.performClose(event)
            }
        }
        
        // Observe viewModel and update status bar (compact format)
        viewModel.$latestTemp
            .combineLatest(viewModel.$latestCO2, viewModel.$latestPM25)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] temp, co2, pm25 in
                guard let self = self else { return }
                
                // If any value missing, show a fallback
                guard let temp = temp, let pm25 = pm25 else {
                    self.statusItem.button?.title = "⚠️"
                    return
                }
                
                // Pick PM2.5 emoji indicator
                let pm25Emoji: String
                switch pm25 {
                case let x where x > 50: pm25Emoji = "🔴"
                case let x where x > 30: pm25Emoji = "🟠"
                case let x where x > 5:  pm25Emoji = "🟡"
                default:                 pm25Emoji = "🟢"
                }
                
                // Compact title: just pm2.5 ppm + emoji
                self.statusItem.button?.title = String(format: "%.0f ppm %@", pm25, pm25Emoji)
            }
            .store(in: &cancellables)
        
        // Initial fetch
        viewModel.fetchLatest()
        viewModel.fetchHistory()
        
        // Periodic fetch every 60s
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.viewModel.fetchLatest()
            self.viewModel.fetchHistory()
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func fetchLatest() {
        guard !viewModel.apiToken.isEmpty else { return }
        viewModel.fetchLatest()
    }
    
    func fetchHistory() {
        guard !viewModel.apiToken.isEmpty, !viewModel.locationID.isEmpty else { return }
        viewModel.fetchHistory()
    }
    
    deinit {
        // Remove monitor when app exits
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
