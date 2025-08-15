//
//  GraphView.swift
//  AirBar
//
//  Created by Matteo Mazzanti on 15.08.2025.
//

import SwiftUI
import Charts

struct DataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pm25: Double?
    let co2: Double?
}

struct GraphView: View {
    @ObservedObject var viewModel: GraphViewModel
    @State private var showingConfig = false
    @Environment(\.colorScheme) var colorScheme
    
    let marginCO2: Double = 40
    let marginpm2: Double = 5
    
    var pm25Values: [Double] {
        viewModel.points.compactMap { $0.pm25 }
    }

    var minPM25: Double {
        pm25Values.min() ?? 0
    }

    var maxPM25: Double {
        pm25Values.max() ?? 1
    }
    
    var CO2Values: [Double] {
        viewModel.points.compactMap { $0.co2 }
    }

    var minCO2: Double {
        CO2Values.min() ?? 0
    }

    var maxCO2: Double {
        CO2Values.max() ?? 1
    }

    var body: some View {
        VStack(spacing: 5) {
            Text("Last 6h Air Data")
                .font(.headline)

            // PM2.5 Chart
            Chart {
                ForEach(viewModel.points.compactMap { $0.pm25 != nil ? $0 : nil }) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("PM2.5", point.pm25!)
                    )
                    .foregroundStyle(colorScheme == .dark ? Color.orange : Color.red)
                    .lineStyle(StrokeStyle(lineWidth: 4.5))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: (minPM25 - (maxPM25-minPM25)*0.2)...(maxPM25 + (maxPM25-minPM25)*0.2))
            .frame(height: 100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 1))
            }
            .chartYAxisLabel("PM2.5 (µg/m³)")

            // CO₂ Chart
            Chart {
                ForEach(viewModel.points.compactMap { $0.co2 != nil ? $0 : nil }) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("CO₂", point.co2!)
                    )
                    .foregroundStyle(colorScheme == .dark ? Color.cyan : Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 4.5))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: (minCO2 - (maxCO2-minCO2)*0.2)...(maxCO2 + (maxCO2-minCO2)*0.2))
            .frame(height: 100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 1))
            }
            .chartYAxisLabel("CO₂ (ppm)")
            
            HStack(spacing: 20) {
                Button("Exit") {
                    NSApplication.shared.terminate(nil)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.red.opacity(0.7) : Color.red.opacity(0.9))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 2, x: 0, y: 1)
                )
                .foregroundColor(.white)
                .buttonStyle(PlainButtonStyle())

                Button("Config") {
                    showingConfig = true
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.blue.opacity(0.7) : Color.blue.opacity(0.9))
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15), radius: 2, x: 0, y: 1)
                )
                .foregroundColor(.white)
                .buttonStyle(PlainButtonStyle())
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
    
    func fetchLatest() {
        guard !apiToken.isEmpty else { return }
        guard let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/measures/current?token=\(apiToken)") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else { return }
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let first = jsonArray.first,
               let temp = first["atmp"] as? Double,
               let co2 = first["rco2_corrected"] as? Double,
               let pm25 = first["pm02_corrected"] as? Double {
                DispatchQueue.main.async {
                    self.latestTemp = temp
                    self.latestCO2 = co2
                    self.latestPM25 = pm25
                }
            }
        }.resume()
    }
    
    func fetchHistory() {
        guard !apiToken.isEmpty, !locationID.isEmpty else { return }
        let now = Date()
        let sixHoursAgo = now.addingTimeInterval(-6 * 3600)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        let fromStr = formatter.string(from: sixHoursAgo)
        let toStr = formatter.string(from: now)
        
        guard let url = URL(string: "https://api.airgradient.com/public/api/v1/locations/\(locationID)/measures/past?token=\(apiToken)&from=\(fromStr)&to=\(toStr)") else { return }
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
                    self.points = newPoints
                }
            }
        }.resume()
    }
    
    func saveConfig() {
        // Save to UserDefaults so it's persistent
        UserDefaults.standard.set(apiToken, forKey: "apiToken")
        UserDefaults.standard.set(locationID, forKey: "locationID")
        
        // Trigger refetch
        fetchLatest()
        fetchHistory()
    }
}
