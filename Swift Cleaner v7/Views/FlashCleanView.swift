import SwiftUI

/// Flash Clean screen:
/// - Reads scan results from `JunkAnalyzer`
/// - Performs cleaning through `FlashCleaner.clean(selected:)`
///
/// Architecture standard:
/// UI owns state + selection (via `JunkAnalyzer`).
/// Services (`FlashCleaner`) expose explicit async APIs (no dynamic member lookup / bindings).
struct FlashCleanView: View {
    @EnvironmentObject private var app: AppController

    @ObservedObject var analyzer: JunkAnalyzer
    @ObservedObject var flash: FlashCleaner

    /// When this UUID changes, the view triggers a scan (used by Home -> FlashClean deep-link).
    let scanRequestID: UUID

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 22) {
                    header

                    if analyzer.progress > 0 && analyzer.progress < 1 {
                        scanProgress
                    }

                    resultsSection
                        .padding(.horizontal, 32)

                    actions

                    statusLine

                    Spacer(minLength: 30)
                }
                .padding(.bottom, 40)
            }
        }
        .onChange(of: scanRequestID) { _, _ in
            startScan()
        }
    }
}

// MARK: - Subviews (split to keep Swift type-checking fast)
private extension FlashCleanView {

    var background: some View {
        Color(red: 0.06, green: 0.10, blue: 0.18)
            .opacity(0.85)
            .ignoresSafeArea()
    }

    var header: some View {
        VStack(spacing: 8) {
            Text("Flash Clean")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Text("Quickly scan and clean junk files from your system")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 24)
    }

    var scanProgress: some View {
        CustomProgressWheelView(
            progress: analyzer.progress,
            title: "Scanning Junk \(analyzer.formatted(analyzer.total))",
            subtitle: analyzer.currentPath,
            color: .blue
        )
        .frame(width: 220, height: 220)
        .padding(.top, 10)
    }

    var resultsSection: some View {
        VStack(spacing: 14) {
            resultsHeader

            if analyzer.categories.isEmpty {
                emptyState
            } else {
                resultsCard
            }
        }
    }

    var resultsHeader: some View {
        HStack {
            Text("Scan Results")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            Menu {
                Button("Sort by Size") { analyzer.sortMode = .sizeDesc }
                Button("Sort by Name") { analyzer.sortMode = .nameAsc }
            } label: {
                Text(analyzer.sortMode.rawValue)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    var emptyState: some View {
        CustomEmptyStateView(
            title: "No Scan Results",
            message: "Click 'Analyze' to scan for junk files on your system.",
            icon: "magnifyingglass",
            actionTitle: "Analyze Now",
            action: { startScan() }
        )
        .frame(height: 280)
    }

    var resultsCard: some View {
        VStack(spacing: 10) {
            ForEach(analyzer.sortedCategories()) { category in
                CategoryRow(
                    name: category.name,
                    description: category.description,
                    sizeText: analyzer.formatted(category.size)
                )
            }

            Divider().opacity(0.2).padding(.vertical, 6)

            HStack {
                Text("Found Junk")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                Text(analyzer.formattedGB(analyzer.total))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    var actions: some View {
        HStack(spacing: 16) {
            Button(action: startScan) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Analyze")
                }
                .frame(width: 150)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.white.opacity(0.2))
            .disabled(flash.isCleaning)

            Button(action: runCleanSelected) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Clean")
                }
                .frame(width: 150)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(analyzer.categories.isEmpty || analyzer.selectedBytes <= 0 || flash.isCleaning)
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    var statusLine: some View {
        if flash.isCleaning {
            VStack(spacing: 8) {
                ProgressView(value: flash.progress)
                    .frame(width: 320)
                Text(flash.current)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.top, 6)
        } else if !flash.current.isEmpty {
            Text(flash.current)
                .font(.caption)
                .foregroundColor(.green)
                .padding(.top, 6)
        }
    }
}

// MARK: - Actions
private extension FlashCleanView {

    func startScan() {
        app.recordScanStarted()
        Task { await analyzer.scan() }
    }

    func runCleanSelected() {
        Task {
            // Standardized: FlashCleaner exposes explicit API `clean(selected:)`
            let cleanedBytes = await flash.clean(selected: analyzer.categories)

            // Record what we actually cleaned (fallback to selected/total if the service returns 0 for some reason)
            let bytesToRecord: Int64 = cleanedBytes > 0
                ? cleanedBytes
                : (analyzer.selectedBytes > 0 ? analyzer.selectedBytes : analyzer.total)

            app.recordClean(bytes: bytesToRecord)
        }
    }
}

/// Light row view to keep the main body simple (helps Swift compiler).
private struct CategoryRow: View {
    let name: String
    let description: String
    let sizeText: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            Text(sizeText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

