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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load saved settings
        let savedToken = UserDefaults.standard.string(forKey: "apiToken") ?? ""
        let savedLocationID = UserDefaults.standard.string(forKey: "locationID") ?? ""
        viewModel = GraphViewModel(apiToken: savedToken, locationID: savedLocationID)
        
        // Setup status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Loading..."
            button.action = #selector(togglePopover(_:))
        }
        
        // Setup popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 250)
        popover.contentViewController = NSHostingController(rootView: GraphView(viewModel: viewModel))
        
        // Observe viewModel and update status bar
        viewModel.$latestTemp
            .combineLatest(viewModel.$latestCO2, viewModel.$latestPM25)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] temp, co2, pm25 in
                guard let temp = temp, let co2 = co2, let pm25 = pm25 else { return }
                
                let pm25Emoji: String
                switch pm25 {
                case let x where x > 50: pm25Emoji = "🔴"
                case let x where x > 30: pm25Emoji = "🟠"
                case let x where x > 5: pm25Emoji = "🟡"
                default: pm25Emoji = "🟢"
                }
                
                self?.statusItem.button?.title = String(format: "%.1f°C - %.0f ppm - %.1fµg/m³ \(pm25Emoji)", temp, co2, pm25)
            }
            .store(in: &cancellables)
        
        // Initial fetch
        viewModel.fetchLatest()
        viewModel.fetchHistory()
        
        // Periodic fetch every 30s
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
}
