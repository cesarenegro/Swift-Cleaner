import SwiftUI

struct MainWindow: View {
    @EnvironmentObject private var app: AppController

    var body: some View {
        AppShellView()
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 10) {

                    Text("Total cleaned:")
                        .foregroundColor(.white.opacity(0.65))
                    Text(app.formattedBytes(app.totalCleaned))
                        .foregroundColor(.white.opacity(0.90))

                    DividerDot()

                    Text("Last scan:")
                        .foregroundColor(.white.opacity(0.65))
                    Text(app.relativeLastScanText())
                        .foregroundColor(.white.opacity(0.90))

                    DividerDot()

                    Text("Last clean:")
                        .foregroundColor(.white.opacity(0.65))
                    Text(app.relativeLastCleanText())
                        .foregroundColor(.white.opacity(0.90))
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(14)
            }
    }
}

private struct DividerDot: View {
    var body: some View {
        Text("•")
            .foregroundColor(.white.opacity(0.45)) // ✅ evita .opacity() (ambiguous)
    }
}

