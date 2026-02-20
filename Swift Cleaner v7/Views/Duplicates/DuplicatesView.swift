import SwiftUI

struct DuplicatesView: View {
    @ObservedObject var dup: DuplicateFinder

    init(dup: DuplicateFinder) {
        self.dup = dup
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.contentTop, AppTheme.contentBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Duplicate Files")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    Text("Find and remove duplicate files to free up space")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.75))
                }
                .padding(.top, 24)
                .padding(.bottom, 16)

                // Progress / Status
                if dup.isLoading {
                    VStack(spacing: 10) {
                        ProgressView(value: dup.progress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .frame(width: 320)

                        Text(dup.statusText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.bottom, 16)
                } else if !dup.statusText.isEmpty {
                    Text(dup.statusText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.bottom, 12)
                }

                Divider().opacity(0.25)

                // Content
                if dup.duplicates.isEmpty && !dup.isLoading {
                    CustomEmptyStateView(
                        title: "No Duplicates Found",
                        message: "Click 'Scan Duplicates' to search for duplicate files.",
                        icon: "doc.on.doc",
                        actionTitle: "Scan Duplicates",
                        action: { runScan() }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 32)
                } else if !dup.duplicates.isEmpty {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Summary
                            HStack {
                                Text("Found \(dup.duplicates.count) duplicate groups")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(dup.duplicates.flatMap { $0 }.count) total files")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            .padding(.horizontal, 32)

                            ForEach(Array(dup.duplicates.enumerated()), id: \.offset) { index, group in
                                DuplicateGroupItemView(index: index, group: group, dup: dup)
                                    .padding(.horizontal, 32)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 60)
                    }
                } else {
                    // Loading state — just show spinner (progress is above)
                    Spacer()
                }

                // Footer
                HStack {
                    Spacer()
                    Button { runScan() } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Scan for Duplicates")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AppTheme.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(dup.isLoading)
                    Spacer()
                }
                .padding(.vertical, 14)
            }
        }
    }

    private func runScan() {
        Task { await dup.scan(at: FileManager.default.homeDirectoryForCurrentUser) }
    }
}
