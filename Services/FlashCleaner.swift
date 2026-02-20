import Foundation
import SwiftUI

@MainActor
final class FlashCleaner: ObservableObject {
    @Published var current: String = "Ready"
    @Published var isCleaning: Bool = false
    @Published var progress: Double = 0

    /// Cleans the selected items. Returns actually cleaned bytes.
    func clean(selected categories: [JunkCategory]) async -> Int64 {
        isCleaning = true
        progress = 0
        current = "Preparing…"

        let items = categories.flatMap { $0.items }.filter { $0.isSelected }

        if items.isEmpty {
            current = "Nothing selected"
            isCleaning = false
            progress = 0
            return 0
        }

        var cleanedBytes: Int64 = 0

        for (idx, item) in items.enumerated() {
            current = "Removing \(item.name)…"
            progress = Double(idx) / Double(items.count)

            let bytesFreed = await Task.detached(priority: .utility) {
                Self.cleanPath(item.path)
            }.value

            cleanedBytes += bytesFreed

            // Small delay for UI feedback
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        progress = 1.0
        let formatted = ByteCountFormatter.string(fromByteCount: cleanedBytes, countStyle: .file)
        current = cleanedBytes > 0
            ? "Cleaned \(formatted)"
            : "Could not remove files (check permissions)"

        try? await Task.sleep(nanoseconds: 300_000_000)

        isCleaning = false
        progress = 0
        return cleanedBytes
    }

    // MARK: - Actual file removal (background thread)

    /// Try to move directory contents to Trash, or delete cache files.
    /// Returns bytes freed.
    nonisolated private static func cleanPath(_ path: String) -> Int64 {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)

        guard fm.fileExists(atPath: path) else { return 0 }

        // Check if it's a file or directory
        var isDir: ObjCBool = false
        fm.fileExists(atPath: path, isDirectory: &isDir)

        if !isDir.boolValue {
            // Single file: trash it
            return trashSingleFile(at: url)
        }

        // Directory: remove contents but keep the directory itself
        // (e.g. ~/Library/Caches — we want to empty it, not delete the folder)
        var freedBytes: Int64 = 0

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else { return 0 }

        for item in contents {
            // Calculate size first
            let itemSize = sizeOf(item)

            do {
                try fm.trashItem(at: item, resultingItemURL: nil)
                freedBytes += itemSize
            } catch {
                // If Trash fails (e.g. sandbox), try direct removal for cache files
                do {
                    try fm.removeItem(at: item)
                    freedBytes += itemSize
                } catch {
                    // Permission denied — skip
                    continue
                }
            }
        }

        return freedBytes
    }

    nonisolated private static func trashSingleFile(at url: URL) -> Int64 {
        let size = sizeOf(url)
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            return size
        } catch {
            do {
                try FileManager.default.removeItem(at: url)
                return size
            } catch {
                return 0
            }
        }
    }

    nonisolated private static func sizeOf(_ url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }

        // Directory: sum all contents
        return JunkAnalyzer.directorySize(atPath: url.path)
    }
}
