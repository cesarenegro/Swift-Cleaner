import Foundation
import SwiftUI

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let size: Int64
    let icon: String
    let path: String
    let bundleIdentifier: String?
    let version: String?
    var subApps: [InstalledApp]?
}

// MARK: - Cache Manager - Isolated to avoid main actor issues
actor SizeCache {
    private var cache: [String: Int64] = [:]
    
    func get(_ key: String) -> Int64? {
        return cache[key]
    }
    
    func set(_ key: String, value: Int64) {
        cache[key] = value
    }
    
    func remove(_ key: String) {
        cache.removeValue(forKey: key)
    }
    
    func clear() {
        cache.removeAll()
    }
}

@MainActor
class AppUninstaller: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var selectedApps = Set<UUID>()
    @Published var isLoading = false
    
    // Use actor for thread-safe cache
    private let sizeCache = SizeCache()
    
    func loadApps() {
        // Don't reload if already loaded
        guard apps.isEmpty else { return }
        
        isLoading = true
        
        Task {
            let applications = await scanApplications()
            await MainActor.run {
                self.apps = applications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.isLoading = false
            }
        }
    }
    
    private func scanApplications() async -> [InstalledApp] {
        var apps: [InstalledApp] = []
        let fileManager = FileManager.default
        
        // Only scan main Applications folder - skip System/Applications for speed
        let appPaths = [
            "/Applications",
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        ]
        
        for appPath in appPaths {
            guard fileManager.fileExists(atPath: appPath),
                  let contents = try? fileManager.contentsOfDirectory(atPath: appPath) else {
                continue
            }
            
            for item in contents where item.hasSuffix(".app") {
                let fullPath = (appPath as NSString).appendingPathComponent(item)
                if let app = await createAppFromPath(fullPath) {
                    apps.append(app)
                }
            }
        }
        
        return apps
    }
    
    private func createAppFromPath(_ path: String) async -> InstalledApp? {
        let url = URL(fileURLWithPath: path)
        let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        
        // Get app info from bundle - FAST
        let bundle = Bundle(url: url)
        let bundleId = bundle?.bundleIdentifier
        let version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
        
        // Map app name to SF Symbol - FAST
        let iconSymbol = mapAppNameToSymbol(name)
        
        // Get app size from cache or calculate in background
        let size = await getAppSize(path: path)
        
        // Quick check for Office-style sub-apps (only for known bundles)
        var subApps: [InstalledApp]? = nil
        if name.contains("Microsoft") || name.contains("Office") {
            subApps = await scanSubApps(in: path)
        }
        
        return InstalledApp(
            name: name,
            size: size,
            icon: iconSymbol,
            path: path,
            bundleIdentifier: bundleId,
            version: version,
            subApps: subApps
        )
    }
    
    private func getAppSize(path: String) async -> Int64 {
        // Check cache first
        if let cachedSize = await sizeCache.get(path) {
            return cachedSize
        }
        
        // Calculate size in background
        let size = await Task.detached(priority: .background) {
            return self.calculateDirectorySize(path: path)
        }.value
        
        // Cache the result
        await sizeCache.set(path, value: size)
        
        return size
    }
    
    // Non-isolated function that doesn't capture self
    private nonisolated func calculateDirectorySize(path: String) -> Int64 {
        let fileManager = FileManager.default
        var size: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(atPath: path) else { return 0 }
        
        while let fileName = enumerator.nextObject() as? String {
            let fullPath = (path as NSString).appendingPathComponent(fileName)
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fullPath)
                if let fileSize = attributes[.size] as? Int64 {
                    size += fileSize
                }
            } catch {
                continue
            }
        }
        
        return size
    }
    
    private func scanSubApps(in bundlePath: String) async -> [InstalledApp] {
        var subApps: [InstalledApp] = []
        let contentsPath = (bundlePath as NSString).appendingPathComponent("Contents")
        
        let helperPaths = [
            (contentsPath as NSString).appendingPathComponent("Helpers"),
            (contentsPath as NSString).appendingPathComponent("Library/LoginItems")
        ]
        
        for helperPath in helperPaths {
            guard FileManager.default.fileExists(atPath: helperPath),
                  let helpers = try? FileManager.default.contentsOfDirectory(atPath: helperPath) else {
                continue
            }
            
            for helper in helpers where helper.hasSuffix(".app") {
                let fullPath = (helperPath as NSString).appendingPathComponent(helper)
                if let app = await createAppFromPath(fullPath) {
                    subApps.append(app)
                }
            }
        }
        
        return subApps
    }
    
    private func mapAppNameToSymbol(_ name: String) -> String {
        let lowercased = name.lowercased()
        
        // Quick dictionary lookup for speed
        if lowercased.contains("xcode") { return "hammer.fill" }
        if lowercased.contains("safari") { return "safari.fill" }
        if lowercased.contains("chrome") { return "globe" }
        if lowercased.contains("firefox") { return "flame.fill" }
        if lowercased.contains("mail") { return "envelope.fill" }
        if lowercased.contains("calendar") { return "calendar" }
        if lowercased.contains("notes") { return "note.text" }
        if lowercased.contains("reminders") { return "checklist" }
        if lowercased.contains("maps") { return "map.fill" }
        if lowercased.contains("photos") { return "photo.fill" }
        if lowercased.contains("music") { return "music.note" }
        if lowercased.contains("podcasts") { return "mic.fill" }
        if lowercased.contains("tv") { return "tv.fill" }
        if lowercased.contains("news") { return "newspaper.fill" }
        if lowercased.contains("stocks") { return "chart.line.uptrend.xyaxis" }
        if lowercased.contains("facetime") { return "video.fill" }
        if lowercased.contains("messages") { return "message.fill" }
        if lowercased.contains("finder") { return "smiley" }
        if lowercased.contains("terminal") { return "terminal.fill" }
        if lowercased.contains("activity monitor") { return "chart.bar.fill" }
        if lowercased.contains("console") { return "terminal" }
        if lowercased.contains("keychain") { return "key.fill" }
        if lowercased.contains("disk utility") { return "internaldrive" }
        if lowercased.contains("slack") { return "message.fill" }
        if lowercased.contains("discord") { return "bubble.left.fill" }
        if lowercased.contains("spotify") { return "music.note" }
        if lowercased.contains("zoom") { return "video.fill" }
        if lowercased.contains("microsoft") { return "folder.fill" }
        if lowercased.contains("word") { return "doc.fill" }
        if lowercased.contains("excel") { return "tablecells.fill" }
        if lowercased.contains("powerpoint") { return "chart.bar.fill" }
        if lowercased.contains("outlook") { return "envelope.fill" }
        if lowercased.contains("teams") { return "person.3.fill" }
        if lowercased.contains("visual studio") { return "hammer.fill" }
        if lowercased.contains("android studio") { return "hammer.fill" }
        if lowercased.contains("python") { return "terminal.fill" }
        
        return "app"
    }
    
    var totalSelectedSize: Int64 {
        var total: Int64 = 0
        for app in apps {
            if selectedApps.contains(app.id) {
                total += app.size
            }
            if let subApps = app.subApps {
                for subApp in subApps {
                    if selectedApps.contains(subApp.id) {
                        total += subApp.size
                    }
                }
            }
        }
        return total
    }
    
    func toggleSelection(for app: InstalledApp) {
        if selectedApps.contains(app.id) {
            selectedApps.remove(app.id)
        } else {
            selectedApps.insert(app.id)
        }
        
        if let subApps = app.subApps {
            for subApp in subApps {
                if selectedApps.contains(app.id) {
                    selectedApps.insert(subApp.id)
                } else {
                    selectedApps.remove(subApp.id)
                }
            }
        }
    }
    
    func remove(_ app: InstalledApp) {
        apps.removeAll { $0.id == app.id }
        selectedApps.remove(app.id)
        
        Task {
            try? FileManager.default.removeItem(atPath: app.path)
            // Remove from cache
            await sizeCache.remove(app.path)
        }
    }
    
    func forceReload() {
        // Clear cache and reload
        Task {
            await sizeCache.clear()
            await MainActor.run {
                self.apps = []
                self.loadApps()
            }
        }
    }
}
