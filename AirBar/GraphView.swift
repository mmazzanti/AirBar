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
    
    @Published var apiToken: String
    @Published var locationID: String
    
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
    
    // MARK: - Data Fetching
    func fetchLatest() {
        guard !apiToken.isEmpty,
              let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/measures/current?token=\(apiToken)")
        else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let first = jsonArray.first
            else { return }
            
            DispatchQueue.main.async {
                self.latestTemp = first["atmp"] as? Double
                self.latestCO2 = first["rco2_corrected"] as? Double
                self.latestPM25 = first["pm02_corrected"] as? Double
            }
        }.resume()
    }
    
    func fetchHistory() {
        guard !apiToken.isEmpty, !locationID.isEmpty else { return }
        let now = Date()
        let sixHoursAgo = now.addingTimeInterval(-6*3600)
        
        let fromStr = GraphViewModel.queryFormatter.string(from: sixHoursAgo)
        let toStr = GraphViewModel.queryFormatter.string(from: now)
        
        guard let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/\(locationID)/measures/past?token=\(apiToken)&from=\(fromStr)&to=\(toStr)")
        else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { return }
            
            var newPoints: [DataPoint] = []
            for item in jsonArray {
                if let ts = item["timestamp"] as? String,
                   let date = GraphViewModel.isoFormatter.date(from: ts) {
                    let pm = item["pm02_corrected"] as? Double
                    let co2 = item["rco2_corrected"] as? Double
                    if pm != nil || co2 != nil {
                        newPoints.append(DataPoint(date: date, pm25: pm, co2: co2))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.points = newPoints
            }
        }.resume()
    }
    
    func saveConfig() {
        UserDefaults.standard.set(apiToken, forKey: "apiToken")
        UserDefaults.standard.set(locationID, forKey: "locationID")
        fetchLatest()
        fetchHistory()
    }
    
    // MARK: - Precomputed filtered arrays
    var pm25Points: [DataPoint] { points.filter { $0.pm25 != nil } }
    var co2Points: [DataPoint] { points.filter { $0.co2 != nil } }
    
    var minPM25: Double { pm25Points.map { $0.pm25! }.min() ?? 0 }
    var maxPM25: Double { pm25Points.map { $0.pm25! }.max() ?? 1 }
    var minCO2: Double { co2Points.map { $0.co2! }.min() ?? 0 }
    var maxCO2: Double { co2Points.map { $0.co2! }.max() ?? 1 }
    
    var pm25Range: ClosedRange<Double> {
        let padding = (maxPM25 - minPM25) * 0.2
        return (minPM25 - padding)...(maxPM25 + padding)
    }
    
    var co2Range: ClosedRange<Double> {
        let padding = (maxCO2 - minCO2) * 0.2
        return (minCO2 - padding)...(maxCO2 + padding)
    }
}

// MARK: - GraphView
struct GraphView: View {
    @ObservedObject var viewModel: GraphViewModel
    @State private var showingConfig = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 5) {
            Text("Last 6h Air Data")
                .font(.headline)
            
            // PM2.5 Chart
            Chart {
                ForEach(viewModel.pm25Points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("PM2.5", point.pm25!)
                    )
                    .foregroundStyle(colorScheme == .dark ? .orange : .red)
                    .lineStyle(StrokeStyle(lineWidth: 4.5))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: viewModel.pm25Range)
            .frame(height: 100)
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 1)) }
            .chartYAxisLabel("PM2.5 (µg/m³)")
            
            // CO2 Chart
            Chart {
                ForEach(viewModel.co2Points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("CO₂", point.co2!)
                    )
                    .foregroundStyle(colorScheme == .dark ? .cyan : .blue)
                    .lineStyle(StrokeStyle(lineWidth: 4.5))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: viewModel.co2Range)
            .frame(height: 100)
            .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 1)) }
            .chartYAxisLabel("CO₂ (ppm)")
            
            // Buttons
            HStack(spacing: 20) {
                StyledButton(title: "Exit", color: .red) { NSApplication.shared.terminate(nil) }
                StyledButton(title: "Config", color: .blue) { showingConfig = true }
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 320, height: 300)
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
