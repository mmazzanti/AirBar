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
        let savedToken = UserDefaults.standard.string(forKey: "apiToken") ?? ""
        let savedLocationID = UserDefaults.standard.string(forKey: "locationID") ?? ""
        viewModel = GraphViewModel(apiToken: savedToken, locationID: savedLocationID)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "Loading..."
            button.action = #selector(togglePopover(_:))
        }
        
        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 250)
        popover.contentViewController = NSHostingController(rootView: GraphView(viewModel: viewModel))
        
        // Observe viewModel and update status bar
        viewModel.$latestTemp.combineLatest(viewModel.$latestCO2, viewModel.$latestPM25)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] temp, co2, pm25 in
                        if let temp = temp, let co2 = co2, let pm25 = pm25 {
                            let pm25Emoji: String
                            if pm25 > 50 {
                                pm25Emoji = "🔴"
                            }
                            else if pm25 > 30{
                                pm25Emoji = "🟠"
                            }
                            else if pm25 > 5 {
                                pm25Emoji = "🟡"
                            } else {
                                pm25Emoji = "🟢"
                            }
                            
                            self?.statusItem.button?.title = String(format: "🌡 %.1f°C 💨 %.0f \(pm25Emoji) %.1fµg/m³", temp, co2, pm25)
                        }
                    }
            .store(in: &cancellables)
        
        viewModel.fetchLatest()
        viewModel.fetchHistory()
        
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.viewModel.fetchLatest()
            self.viewModel.fetchHistory()
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
            if let button = statusItem.button {
                if popover.isShown {
                    popover.performClose(sender)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    
    func fetchLatest() {
        guard !viewModel.apiToken.isEmpty else { return }
        guard let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/measures/current?token=\(viewModel.apiToken)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = jsonArray.first,
               let temp = first["atmp"] as? Double,
               let humidity = first["rhum"] as? Double,
               let CO2 = first["rco2_corrected"] as? Double,
               let pm25 = first["pm02_corrected"] as? Double {
                DispatchQueue.main.async {
                    self.statusItem.button?.title = String(format: "🌡 %.1f°C 💨 %.0f 🟢 %.1fµg/m³", temp, CO2, pm25)
                }
            }
        }.resume()
    }
    
    func fetchHistory() {
        guard !viewModel.apiToken.isEmpty, !viewModel.locationID.isEmpty else { return }
        let now = Date()
        let sixHoursAgo = now.addingTimeInterval(-6 * 3600)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let fromStr = formatter.string(from: sixHoursAgo)
        let toStr = formatter.string(from: now)
        
        guard let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/\(viewModel.locationID)/measures/past?token=\(viewModel.apiToken)&from=\(fromStr)&to=\(toStr)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                var newPoints: [DataPoint] = []
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                for item in jsonArray {
                    if let ts = item["timestamp"] as? String,
                       let date = dateFormatter.date(from: ts) {
                        
                        let pm = item["pm02_corrected"] as? Double
                        let co2 = item["rco2_corrected"] as? Double
                        
                        if pm != nil || co2 != nil {
                            newPoints.append(DataPoint(date: date, pm25: pm, co2: co2))
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.viewModel.points = newPoints
                    self.popover.contentViewController = NSHostingController(rootView: GraphView(viewModel: self.viewModel))
                }
            }
        }.resume()
    }
}
