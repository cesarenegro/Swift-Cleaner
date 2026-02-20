import SwiftUI

struct DuplicateGroupItemView: View {
    let index: Int
    let group: [URL]
    let dup: DuplicateFinder

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Group \(index + 1)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(group.count) files")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }

            ForEach(group.prefix(3), id: \.path) { file in
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.white.opacity(0.7))
                    Text(file.lastPathComponent)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Button("Delete") {
                        dup.remove(file: file)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.8))
                }
            }

            if group.count > 3 {
                Text("... and \(group.count - 3) more files")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.leading, 24)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}
