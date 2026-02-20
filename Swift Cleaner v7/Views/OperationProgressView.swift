import SwiftUI

struct OperationProgressView: View {
    @State private var progress: Double = 0
    @State private var currentOperation = "Preparing Smart Clean..."
    @State private var operationDetail = "Analyzing your Mac"
    @State private var isSmartClean = true
    
    let operations = [
        "Scanning system cache...",
        "Analyzing application data...",
        "Checking for duplicates...",
        "Identifying large files...",
        "Cleaning temporary files...",
        "Optimizing storage...",
        "Finalizing..."
    ]
    
    let details = [
        "This may take a moment",
        "Finding junk files",
        "Looking for duplicate documents",
        "Searching files >100MB",
        "Removing unnecessary data",
        "Freeing up disk space",
        "Almost done!"
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .symbolEffect(.bounce, options: .repeating, value: progress)
            }
            
            Text("Smart Clean")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.purple)
                    .frame(width: 300)
                
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(currentOperation)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(operationDetail)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            
            HStack(spacing: 16) {
                Label("⌘S", systemImage: "command")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Text("•")
                    .foregroundColor(.white.opacity(0.5))
                Label("Cancel", systemImage: "xmark.circle")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(32)
        .frame(width: 400, height: 450)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .shadow(color: .purple.opacity(0.2), radius: 20)
        )
        .onAppear {
            startProgress()
        }
    }
    
    private func startProgress() {
        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.2)) {
                if progress < 1.0 {
                    progress += 0.01
                    let index = min(Int(progress * Double(operations.count)), operations.count - 1)
                    currentOperation = operations[index]
                    operationDetail = details[index]
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

#Preview {
    OperationProgressView()
        .frame(width: 500, height: 550)
}
