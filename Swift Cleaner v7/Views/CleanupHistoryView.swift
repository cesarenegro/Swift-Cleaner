//
//  CleanupHistoryView.swift
//  Swift Cleaner
//
//  Created by APPLE on 12/2/2026.
//


//
//  CleanupHistoryView.swift
//  Swift Cleaner
//
//  Created by APPLE on 12/2/2026.
//

import SwiftUI

struct CleanupHistoryView: View {
    @StateObject private var history = CleanupHistoryManager.shared
    @State private var selectedTimeframe = 0
    @State private var showClearConfirmation = false
    
    let timeframes = ["Week", "Month", "All Time"]
    
    var filteredSessions: [CleanupHistoryManager.CleanupSession] {
        switch selectedTimeframe {
        case 0: return history.getSessions(in: 7)
        case 1: return history.getSessions(in: 30)
        default: return history.sessions
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cleanup History")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Track your Mac's optimization journey")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total Space Saved")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(history.totalSpaceSaved.formattedSize)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Summary cards
            HStack(spacing: 16) {
                StatCard(
                    icon: "calendar",
                    title: "Cleanups",
                    value: "\(history.sessions.count)",
                    color: .blue
                )
                
                StatCard(
                    icon: "arrow.down.circle",
                    title: "Avg. Per Clean",
                    value: history.averagePerSession.formattedSize,
                    color: .green
                )
                
                StatCard(
                    icon: "flame",
                    title: "Best Clean",
                    value: history.sessions.max(by: { $0.size < $1.size })?.size.formattedSize ?? "0",
                    color: .orange
                )
            }
            .padding(.horizontal)
            
            // Timeframe selector
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(0..<timeframes.count, id: \.self) { index in
                    Text(timeframes[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            // History list
            List {
                ForEach(filteredSessions) { session in
                    HStack {
                        Image(systemName: session.type.icon)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(session.type.color)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.type.rawValue)
                                .font(.headline)
                            
                            HStack(spacing: 4) {
                                Text(session.date.shortFormatted)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text("\(session.itemCount) items")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(session.size.formattedSize)
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            
            // Footer
            HStack {
                Spacer()
                
                Button("Export Report") {
                    exportReport()
                }
                .buttonStyle(.bordered)
                
                Button(role: .destructive) {
                    showClearConfirmation = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .confirmationDialog(
                    "Clear Cleanup History?",
                    isPresented: $showClearConfirmation,
                    actions: {
                        Button("Cancel", role: .cancel) { }
                        Button("Clear History", role: .destructive) {
                            history.clearHistory()
                        }
                    },
                    message: {
                        Text("This will permanently delete all cleanup history.")
                    }
                )
            }
            .padding()
            .background(.bar)
        }
    }
    
    private func exportReport() {
        var report = "Date,Type,Size (Bytes),Size (Human),Items,Details\n"
        
        for session in history.sessions {
            let dateStr = ISO8601DateFormatter().string(from: session.date)
            let detailsStr = session.details.joined(separator: "; ")
            report += "\(dateStr),\(session.type.rawValue),\(session.size),\"\(session.size.formattedSize)\",\(session.itemCount),\"\(detailsStr)\"\n"
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Export Cleanup Report"
        savePanel.nameFieldStringValue = "SwiftCleaner_Report_\(Date().dayOnly).csv"
        savePanel.allowedContentTypes = [.commaSeparatedText]
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? report.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}