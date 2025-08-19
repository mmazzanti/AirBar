//
//  GraphView.swift
//  AirBar
//
//  Created by Matteo Mazzanti on 15.08.2025.
//

import SwiftUI
import Charts

// MARK: - Data Model
struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pm25: Double?
    let co2: Double?
}

// MARK: - ViewModel
class GraphViewModel: ObservableObject {
    @Published var points: [DataPoint] = []
    @Published var latestTemp: Double?
    @Published var latestCO2: Double?
    @Published var latestPM25: Double?
    @Published var latestPM01: Double?
    @Published var latestPM10: Double?
    @Published var latestNOX: Double?
    @Published var latestHumidity: Double?
    
    @Published var apiToken: String
    @Published var locationID: String
    
    @Published var hasError: Bool = false
    
    init(apiToken: String = "", locationID: String = "") {
        self.apiToken = apiToken
        self.locationID = locationID
    }
    
    // Reuse formatters
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    static let queryFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()
    
    // MARK: - Helpers (timeline & rounding)
    private func floorToFiveMinutes(_ date: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let m = comps.minute ?? 0
        comps.minute = (m / 5) * 5
        comps.second = 0
        comps.nanosecond = 0
        return cal.date(from: comps) ?? date
    }
    
    private func buildTimeline(from start: Date, to end: Date, stepMinutes: Int = 5,
                               map: [Date: (Double?, Double?)]) -> [DataPoint] {
        var timeline: [DataPoint] = []
        var t = start
        while t <= end {
            let vals = map[t] ?? (nil, nil)
            timeline.append(DataPoint(date: t, pm25: vals.0, co2: vals.1))
            t = Calendar.current.date(byAdding: .minute, value: stepMinutes, to: t)!
        }
        return timeline
    }
    
    // MARK: - Data Fetching
    func fetchLatest() {
        guard !apiToken.isEmpty,
              let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/measures/current?token=\(apiToken)")
        else {
            DispatchQueue.main.async { self.hasError = true }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = jsonArray.first
            else {
                DispatchQueue.main.async { self.hasError = true }
                return
            }
            
            DispatchQueue.main.async {
                // Use the keys you showed in your sample JSON
                self.latestTemp     = first["atmp"] as? Double
                self.latestCO2      = first["rco2_corrected"] as? Double
                self.latestPM25     = first["pm02_corrected"] as? Double
                self.latestPM01     = first["pm01_corrected"] as? Double
                self.latestPM10     = first["pm10_corrected"] as? Double
                self.latestNOX      = first["noxIndex"] as? Double
                self.latestHumidity = first["rhum"] as? Double
                self.hasError = false
            }
        }.resume()
    }
    
    func fetchHistory() {
        guard !apiToken.isEmpty, !locationID.isEmpty else {
            DispatchQueue.main.async { self.hasError = true }
            return
        }
        
        let now = Date()
        let sixHoursAgo = now.addingTimeInterval(-6*3600)
        
        let fromStr = GraphViewModel.queryFormatter.string(from: sixHoursAgo)
        let toStr = GraphViewModel.queryFormatter.string(from: now)
        
        guard let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/\(locationID)/measures/past?token=\(apiToken)&from=\(fromStr)&to=\(toStr)")
        else {
            DispatchQueue.main.async { self.hasError = true }
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else {
                DispatchQueue.main.async { self.hasError = true }
                return
            }
            
            // Map API rows onto a 5-min grid by flooring to 5-minute buckets
            var map: [Date: (Double?, Double?)] = [:]
            for item in jsonArray {
                if let ts = item["timestamp"] as? String,
                   let date = GraphViewModel.isoFormatter.date(from: ts) {
                    let bucket = self.floorToFiveMinutes(date)
                    let pm = item["pm02_corrected"] as? Double
                    let co2 = item["rco2_corrected"] as? Double
                    map[bucket] = (pm, co2)
                }
            }
            
            // Build uniform timeline over the last 6h; nils create visible gaps
            let filled = self.buildTimeline(from: self.floorToFiveMinutes(sixHoursAgo),
                                            to: self.floorToFiveMinutes(now),
                                            stepMinutes: 5,
                                            map: map)
            
            DispatchQueue.main.async {
                self.points = filled
                self.hasError = false
            }
        }.resume()
    }
    
    func saveConfig() {
        UserDefaults.standard.set(apiToken, forKey: "apiToken")
        UserDefaults.standard.set(locationID, forKey: "locationID")
        fetchLatest()
        fetchHistory()
    }
    
    // MARK: - Precomputed filtered arrays (for y-range)
    var pm25Points: [DataPoint] { points.filter { $0.pm25 != nil } }
    var co2Points: [DataPoint] { points.filter { $0.co2 != nil } }
    
    var minPM25: Double { pm25Points.map { $0.pm25! }.min() ?? 0 }
    var maxPM25: Double { pm25Points.map { $0.pm25! }.max() ?? 1 }
    var minCO2: Double { co2Points.map { $0.co2! }.min() ?? 0 }
    var maxCO2: Double { co2Points.map { $0.co2! }.max() ?? 1 }
    
    var pm25Range: ClosedRange<Double> {
        let span = maxPM25 - minPM25
        let padding = (span == 0 ? 1 : span) * 0.2
        return (minPM25 - padding)...(maxPM25 + padding)
    }
    
    var co2Range: ClosedRange<Double> {
        let span = maxCO2 - minCO2
        let padding = (span == 0 ? 1 : span) * 0.2
        return (minCO2 - padding)...(maxCO2 + padding)
    }
}

// MARK: - GraphView
struct GraphView: View {
    @ObservedObject var viewModel: GraphViewModel
    @State private var showingConfig = false
    @Environment(\.colorScheme) var colorScheme
    
    // Always use a trailing 6h domain
    private var xDomain: ClosedRange<Date> {
        let now = Date()
        return (now.addingTimeInterval(-6*3600))...now
    }
    
    var body: some View {
        VStack(spacing: 8) {
            if viewModel.hasError {
                Text("⚠️ Connection error")
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
            } else {
                // Two centered summary lines (short labels)
                VStack(spacing: 4) {
                    if let t = viewModel.latestTemp,
                       let h = viewModel.latestHumidity,
                       let c = viewModel.latestCO2 {
                        Text(String(format: "%.1f °C  •  %.0f %%  •  %.0f ppm", t, h, c))
                    }
                    if let pm01 = viewModel.latestPM01,
                       let pm25 = viewModel.latestPM25,
                       let pm10 = viewModel.latestPM10,
                       let tvoc = viewModel.latestNOX ?? viewModel.latestPM10 { // keep NOx optional; fallback no-op
                        // If you want TVOC instead of NOx, replace tvoc binding with latestTVOC when you add it
                        let tvocShown = viewModel.latestNOX != nil ? "NOx" : "TVOC"
                        Text(String(format: "PM1 %.1f  •  PM2.5 %.1f  •  \(tvocShown) %.f",
                                    pm01, pm25, tvoc))
                    }
                }
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
                
                Divider()
                
                Text("Last 6 hours")
                    .font(.headline)
                
                // PM2.5 Chart (uses optional y to create gaps)
                Chart {
                    ForEach(viewModel.points) { point in
                        if let pm25 = point.pm25 {
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("PM2.5", pm25) // Double? -> gaps when nil
                            )
                            .foregroundStyle(colorScheme == .dark ? .orange : .red)
                            .lineStyle(StrokeStyle(lineWidth: 3.0))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: viewModel.pm25Range)
                .frame(height: 100)
                .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 1)) }
                .chartYAxisLabel("PM2.5 (µg/m³)")
                
                // CO2 Chart (uses optional y to create gaps)
                Chart {
                    ForEach(viewModel.points) { point in
                        if let co2 = point.co2 {
                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("CO₂", co2) // Double? -> gaps when nil
                            )
                            .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                            .lineStyle(StrokeStyle(lineWidth: 3.0))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartXScale(domain: xDomain)
                .chartYScale(domain: viewModel.co2Range)
                .frame(height: 100)
                .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 1)) }
                .chartYAxisLabel("CO₂ (ppm)")
            }
            
            // Buttons always visible
            HStack(spacing: 20) {
                StyledButton(title: "Exit", color: .red) { NSApplication.shared.terminate(nil) }
                StyledButton(title: "Config", color: .blue) { showingConfig = true }
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 320, height: 350)
        .sheet(isPresented: $showingConfig) {
            ConfigView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.fetchLatest()
            viewModel.fetchHistory()
        }
    }
}

// MARK: - Reusable Styled Button
struct StyledButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(title, action: action)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? color.opacity(0.7) : color.opacity(0.9))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 2, x: 0, y: 1)
            )
            .foregroundColor(.white)
            .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - ConfigView
struct ConfigView: View {
    @ObservedObject var viewModel: GraphViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Configuration").font(.headline)
            
            TextField("API Token", text: $viewModel.apiToken)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            TextField("Location ID", text: $viewModel.locationID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            
            Button("Save") {
                viewModel.saveConfig()
                presentationMode.wrappedValue.dismiss()
            }
            .padding(.top)
        }
        .frame(width: 300, height: 150)
    }
}
