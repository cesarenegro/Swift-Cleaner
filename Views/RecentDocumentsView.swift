//
//  RecentDocumentsView.swift
//  Swift Cleaner
//
//  Created by APPLE on 12/2/2026.
//


//
//  RecentDocumentsView.swift
//  Swift Cleaner
//
//  Created by APPLE on 12/2/2026.
//

import SwiftUI

struct RecentDocumentsView: View {
    @StateObject private var cleaner = RecentDocumentsCleaner()
    @State private var isScanning = false
    @State private var selectedItems = Set<UUID>()
    @State private var showClearConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Documents")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Clear recent files lists from Finder and apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    Task {
                        isScanning = true
                        await cleaner.scan()
                        isScanning = false
                    }
                } label: {
                    HStack {
                        if isScanning {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text("Scan")
                    }
                    .frame(width: 80)
                }
                .disabled(isScanning)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            if cleaner.recentItems.isEmpty && !isScanning {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .opacity(0.7)
                    
                    Text("No Recent Documents Found")
                        .font(.headline)
                    
                    Text("Click Scan to check for recent files lists")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                // Stats bar
                HStack {
                    if !selectedItems.isEmpty {
                        Label("\(selectedItems.count) selected", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Label("\(cleaner.recentItems.count) items", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Label(cleaner.totalSize.formattedSize, systemImage: "arrow.down.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if !selectedItems.isEmpty {
                        Button("Select All") {
                            selectedItems = Set(cleaner.recentItems.map { $0.id })
                        }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                        
                        Button("Clear Selected") {
                            showClearConfirmation = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                // List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(cleaner.recentItems) { item in
                            RecentItemRow(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                onSelect: {
                                    if selectedItems.contains(item.id) {
                                        selectedItems.remove(item.id)
                                    } else {
                                        selectedItems.insert(item.id)
                                    }
                                },
                                onDelete: {
                                    Task {
                                        await cleaner.clearItem(item)
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Footer
            if !cleaner.recentItems.isEmpty && !isScanning {
                HStack {
                    Spacer()
                    
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear All Recent Items", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .confirmationDialog(
                        "Clear All Recent Documents?",
                        isPresented: $showClearConfirmation,
                        actions: {
                            Button("Cancel", role: .cancel) { }
                            Button("Clear All", role: .destructive) {
                                Task {
                                    _ = await cleaner.clearAllRecents()
                                    selectedItems.removeAll()
                                }
                            }
                        },
                        message: {
                            Text("This will clear recent documents lists from Finder and all applications.")
                        }
                    )
                }
                .padding()
                .background(.bar)
            }
        }
    }
}

struct RecentItemRow: View {
    let item: RecentDocumentsCleaner.RecentItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                HStack(spacing: 4) {
                    Text(item.application)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.application == "Finder" ? Color.blue.opacity(0.2) : Color.purple.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(item.formattedDate)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(item.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(isHovered ? 1 : 0.7))
            }
            .buttonStyle(.plain)
            .help("Delete this recent items list")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}