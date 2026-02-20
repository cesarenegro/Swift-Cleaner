import Foundation
import SwiftUI
import CryptoKit

@MainActor
class DuplicateFinder: ObservableObject {
    @Published var duplicates: [[URL]] = []
    @Published var progress: Double = 0
    @Published var isLoading: Bool = false
    @Published var statusText: String = ""

    /// Minimum file size to consider (skip tiny files) — 1 KB
    private let minFileSize: Int64 = 1024

    // MARK: - Real Scan

    func scan(at rootURL: URL) async {
        isLoading = true
        progress = 0
        duplicates = []
        statusText = "Collecting files…"

        // Step 1: Collect all regular files with sizes
        let allFiles = await Task.detached(priority: .utility) {
            Self.collectFiles(at: rootURL, minSize: self.minFileSize)
        }.value

        statusText = "Found \(allFiles.count) files. Grouping by size…"
        progress = 0.2

        // Step 2: Group by file size (quick filter — files must be same size to be duplicates)
        let sizeGroups = Dictionary(grouping: allFiles) { $0.size }
        let potentialDupes = sizeGroups.filter { $0.value.count > 1 }

        let totalGroups = potentialDupes.count
        guard totalGroups > 0 else {
            statusText = "No potential duplicates found."
            isLoading = false
            progress = 0
            return
        }

        statusText = "\(totalGroups) size groups. Comparing file hashes…"
        progress = 0.4

        // Step 3: For each size group, compute partial hash to find true duplicates
        var confirmedGroups: [[URL]] = []
        var processed = 0

        for (_, group) in potentialDupes {
            processed += 1
            progress = 0.4 + 0.6 * Double(processed) / Double(totalGroups)

            let urls = group.map { $0.url }

            let hashGroups = await Task.detached(priority: .utility) {
                Self.groupByHash(urls: urls)
            }.value

            for hashGroup in hashGroups where hashGroup.count > 1 {
                confirmedGroups.append(hashGroup)
            }

            // Yield periodically so UI stays responsive
            if processed % 20 == 0 {
                try? await Task.sleep(nanoseconds: 10_000_000)
                duplicates = confirmedGroups.sorted { $0.count > $1.count }
            }
        }

        duplicates = confirmedGroups.sorted { $0.count > $1.count }
        statusText = confirmedGroups.isEmpty
            ? "No duplicate files found."
            : "Found \(confirmedGroups.count) duplicate groups (\(confirmedGroups.flatMap { $0 }.count) files)"
        isLoading = false
        progress = 0
    }

    // MARK: - Remove

    func remove(file: URL) {
        do {
            try FileManager.default.trashItem(at: file, resultingItemURL: nil)
        } catch {
            print("Failed to trash \(file.path): \(error.localizedDescription)")
        }

        // Update UI
        for i in 0..<duplicates.count {
            duplicates[i].removeAll { $0 == file }
        }
        duplicates.removeAll { $0.count <= 1 }
    }

    // MARK: - Background helpers

    private struct FileEntry {
        let url: URL
        let size: Int64
    }

    nonisolated private static func collectFiles(at root: URL, minSize: Int64) -> [FileEntry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }

        var entries: [FileEntry] = []

        // Scan user content folders (skip Library to keep it fast)
        let scanDirs = [
            root.appendingPathComponent("Downloads"),
            root.appendingPathComponent("Documents"),
            root.appendingPathComponent("Desktop"),
            root.appendingPathComponent("Pictures"),
            root.appendingPathComponent("Music"),
            root.appendingPathComponent("Movies")
        ]

        for dir in scanDirs {
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let fileURL as URL in enumerator {
                do {
                    let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                    if values.isRegularFile == true, let size = values.fileSize, Int64(size) >= minSize {
                        entries.append(FileEntry(url: fileURL, size: Int64(size)))
                    }
                } catch {
                    continue
                }
            }
        }
        return entries
    }

    /// Hash first 8 KB of each file — fast and sufficient to detect duplicates
    nonisolated private static func groupByHash(urls: [URL]) -> [[URL]] {
        var hashMap: [String: [URL]] = [:]

        for url in urls {
            guard let hash = partialHash(of: url) else { continue }
            hashMap[hash, default: []].append(url)
        }

        return Array(hashMap.values.filter { $0.count > 1 })
    }

    nonisolated private static func partialHash(of url: URL, bytesToRead: Int = 8192) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let data = handle.readData(ofLength: bytesToRead)
        guard !data.isEmpty else { return nil }

        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
