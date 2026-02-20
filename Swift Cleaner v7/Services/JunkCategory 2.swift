import Foundation
import SwiftUI

// MARK: - JunkCategory model

struct JunkCategory: Identifiable, Hashable {
    let id: UUID
    let key: String
    let name: String
    let description: String
    var size: Int64
    var isSelected: Bool
    var items: [JunkItem]

    init(
        id: UUID = UUID(),
        key: String,
        name: String,
        description: String,
        size: Int64 = 0,
        isSelected: Bool = false,
        items: [JunkItem] = []
    ) {
        self.id = id
        self.key = key
        self.name = name
        self.description = description
        self.size = size
        self.isSelected = isSelected
        self.items = items
    }

    var selectedSize: Int64 {
        if items.isEmpty { return isSelected ? size : 0 }
        return items.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }
}

// MARK: - JunkAnalyzer (REAL disk scan)

@MainActor
final class JunkAnalyzer: ObservableObject {

    enum ScreenState: Equatable {
        case idle, scanning, summary, details
    }

    @Published var categories: [JunkCategory] = []
    @Published var total: Int64 = 0
    @Published var progress: Double = 0
    @Published var currentPath: String = ""
    @Published var state: ScreenState = .idle
    @Published var selectedCategoryID: UUID?
    @Published var smartSelectedBytes: Int64 = 0

    enum SortMode: String, CaseIterable {
        case sizeDesc = "Sort by Size"
        case nameAsc = "Sort by Name"
    }
    @Published var sortMode: SortMode = .sizeDesc

    var selectedBytes: Int64 {
        categories.reduce(0) { $0 + $1.selectedSize }
    }

    func formatted(_ size: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    func formattedGB(_ size: Int64) -> String {
        let gb = Double(size) / 1_073_741_824.0
        return String(format: "%.2f GB", gb)
    }

    func category(by id: UUID?) -> JunkCategory? {
        guard let id else { return nil }
        return categories.first(where: { $0.id == id })
    }

    func sortedCategories() -> [JunkCategory] {
        switch sortMode {
        case .sizeDesc: return categories.sorted { $0.size > $1.size }
        case .nameAsc:  return categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    func deselectAll() {
        for c in categories.indices {
            categories[c].isSelected = false
            for i in categories[c].items.indices { categories[c].items[i].isSelected = false }
        }
        recomputeSmartSelectedBytes()
    }

    func applySmartSelection() {
        for c in categories.indices {
            for i in categories[c].items.indices {
                categories[c].items[i].isSelected = categories[c].items[i].isRecommended
            }
            categories[c].isSelected = categories[c].items.allSatisfy { $0.isSelected }
        }
        recomputeSmartSelectedBytes()
    }

    func toggleCategory(_ id: UUID, to newValue: Bool) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[idx].isSelected = newValue
        for j in categories[idx].items.indices { categories[idx].items[j].isSelected = newValue }
        recomputeSmartSelectedBytes()
    }

    func toggleItem(categoryID: UUID, itemID: UUID, to newValue: Bool) {
        guard let c = categories.firstIndex(where: { $0.id == categoryID }) else { return }
        guard let i = categories[c].items.firstIndex(where: { $0.id == itemID }) else { return }
        categories[c].items[i].isSelected = newValue
        let all = categories[c].items.allSatisfy { $0.isSelected }
        let none = categories[c].items.allSatisfy { !$0.isSelected }
        categories[c].isSelected = all ? true : (none ? false : true)
        recomputeSmartSelectedBytes()
    }

    // MARK: - REAL SCAN

    func scan() async {
        state = .scanning
        progress = 0
        total = 0
        smartSelectedBytes = 0
        currentPath = ""
        categories = []

        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Define scan targets: (key, name, description, paths, isRecommended)
        let targets: [(String, String, String, [(String, String, Bool)])] = [
            ("user_cache", "User Caches",
             "Application caches that can be safely regenerated",
             [
                ("User Caches", "\(home)/Library/Caches", true)
             ]),

            ("system_logs", "System Logs",
             "Log files from macOS and applications",
             [
                ("User Logs", "\(home)/Library/Logs", true),
                ("Diagnostic Reports", "\(home)/Library/Logs/DiagnosticReports", true)
             ]),

            ("xcode", "Xcode Junk",
             "Build data, simulators, and caches from Xcode",
             [
                ("DerivedData", "\(home)/Library/Developer/Xcode/DerivedData", true),
                ("Archives", "\(home)/Library/Developer/Xcode/Archives", false),
                ("iOS DeviceSupport", "\(home)/Library/Developer/Xcode/iOS DeviceSupport", false),
                ("CoreSimulator", "\(home)/Library/Developer/CoreSimulator/Devices", false),
                ("Xcode Caches", "\(home)/Library/Caches/com.apple.dt.Xcode", true)
             ]),

            ("browser", "Browser Cache",
             "Temporary browser data for faster page loading",
             [
                ("Safari Cache", "\(home)/Library/Caches/com.apple.Safari", true),
                ("Chrome Cache", "\(home)/Library/Caches/Google/Chrome", true),
                ("Firefox Cache", "\(home)/Library/Caches/Firefox", true),
                ("Edge Cache", "\(home)/Library/Caches/com.microsoft.edgemac", true),
                ("Brave Cache", "\(home)/Library/Caches/BraveSoftware", true)
             ]),

            ("mail", "Mail Attachments",
             "Downloaded mail attachments and data",
             [
                ("Mail Downloads", "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads", false),
                ("Mail Data", "\(home)/Library/Mail", false)
             ]),

            ("temp", "Temporary Files",
             "System and application temporary files",
             [
                ("Tmp", "/tmp", true),
                ("User Tmp", "\(home)/.Trash", false)
             ]),

            ("app_support", "Application Leftovers",
             "Support files from apps that may no longer be installed",
             [
                ("Application Support", "\(home)/Library/Application Support", false),
                ("Preferences", "\(home)/Library/Preferences", false)
             ])
        ]

        let totalTargets = targets.flatMap { $0.3 }.count
        var scanned = 0
        var built: [JunkCategory] = []

        for target in targets {
            var items: [JunkItem] = []

            for (itemName, path, recommended) in target.3 {
                currentPath = path
                scanned += 1
                progress = Double(scanned) / Double(totalTargets)

                let size = await Task.detached(priority: .utility) {
                    Self.directorySize(atPath: path)
                }.value

                // Only include if something is actually there
                if size > 0 {
                    items.append(JunkItem(
                        name: itemName,
                        path: path,
                        size: size,
                        isSelected: recommended,
                        isRecommended: recommended
                    ))
                }

                // Small delay so the UI updates smoothly
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            if !items.isEmpty {
                let catSize = items.reduce(0) { $0 + $1.size }
                let allSelected = items.allSatisfy { $0.isSelected }
                built.append(JunkCategory(
                    key: target.0,
                    name: target.1,
                    description: target.2,
                    size: catSize,
                    isSelected: allSelected,
                    items: items
                ))
            }
        }

        categories = built
        total = built.reduce(0) { $0 + $1.size }
        selectedCategoryID = categories.first?.id
        recomputeSmartSelectedBytes()

        state = .summary
        progress = 1
        currentPath = ""
    }

    // MARK: - Helpers

    private func recomputeSmartSelectedBytes() {
        smartSelectedBytes = selectedBytes
    }

    /// Calculate real directory size (runs off main thread)
    nonisolated static func directorySize(atPath path: String) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return 0 }

        var totalSize: Int64 = 0

        // Use enumerator for deep traversal
        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true } // skip errors, keep going
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if values.isRegularFile == true, let size = values.fileSize {
                    totalSize += Int64(size)
                }
            } catch {
                continue
            }
        }
        return totalSize
    }
}
