import SwiftUI

struct AvatarView: View {
    @Environment(\.matrixService) private var matrixService
    let name: String
    let mxcURL: String?
    let size: CGFloat

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .task(id: mxcURL) {
            guard let mxcURL else { return }
            image = await matrixService.avatarThumbnail(mxcURL: mxcURL, size: size)
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(color(for: name))

            Text(initials(for: name))
                .font(.system(size: size * 0.4, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private func initials(for name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func color(for name: String) -> Color {
        let hash = abs(name.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.5, brightness: 0.7)
    }
}

#Preview("Initials") {
    HStack(spacing: 16) {
        AvatarView(name: "Alice Smith", mxcURL: nil, size: 48)
        AvatarView(name: "Bob", mxcURL: nil, size: 36)
        AvatarView(name: "Charlie Davis", mxcURL: nil, size: 28)
    }
    .padding()
}

#Preview("Sizes") {
    VStack(spacing: 12) {
        AvatarView(name: "Relay User", mxcURL: nil, size: 64)
        AvatarView(name: "Relay User", mxcURL: nil, size: 36)
        AvatarView(name: "Relay User", mxcURL: nil, size: 24)
    }
    .padding()
}
