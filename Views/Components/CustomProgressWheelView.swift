import SwiftUI

struct CustomProgressWheelView: View {
    let progress: Double
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 10)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)
                
                // Percentage text
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 120, height: 120)
            
            // Title and subtitle
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Preview
struct CustomProgressWheelView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CustomProgressWheelView(
                progress: 0.65,
                title: "Scanning...",
                subtitle: "2.4 GB found",
                color: .blue
            )
            .frame(width: 200, height: 200)
            .padding()
            .previewDisplayName("65% Progress")
            
            CustomProgressWheelView(
                progress: 1.0,
                title: "Complete!",
                subtitle: "Scan finished",
                color: .green
            )
            .frame(width: 200, height: 200)
            .padding()
            .previewDisplayName("100% Complete")
            
            CustomProgressWheelView(
                progress: 0.25,
                title: "Cleaning...",
                subtitle: "Removing junk files",
                color: .orange
            )
            .frame(width: 200, height: 200)
            .padding()
            .previewDisplayName("25% Progress")
        }
    }
}