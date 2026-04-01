import LinkPresentation
import SwiftUI

// MARK: - Metadata Cache

/// A global, thread-safe cache for fetched link metadata, preventing redundant network
/// requests when cells are reused during scrolling.
actor LinkMetadataCache {
    static let shared = LinkMetadataCache()

    private var cache: [URL: LPLinkMetadata] = [:]
    private var inFlight: [URL: Task<LPLinkMetadata?, Never>] = [:]

    /// Returns cached metadata immediately, or fetches it asynchronously.
    func metadata(for url: URL) async -> LPLinkMetadata? {
        if let cached = cache[url] { return cached }

        // Coalesce concurrent requests for the same URL.
        if let existing = inFlight[url] {
            return await existing.value
        }

        let task = Task<LPLinkMetadata?, Never> {
            let provider = LPMetadataProvider()
            do {
                let metadata = try await provider.startFetchingMetadata(for: url)
                cache[url] = metadata
                return metadata
            } catch {
                return nil
            }
        }

        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        return result
    }
}

// MARK: - LinkPreviewView

/// Displays a rich link preview card for a URL using the system `LPLinkView`.
///
/// Metadata is fetched asynchronously via `LPMetadataProvider` and cached globally
/// so that scrolling through the timeline doesn't re-fetch.
struct LinkPreviewView: View {
    let url: URL
    let isOutgoing: Bool

    @State private var metadata: LPLinkMetadata?
    @State private var didFail = false

    var body: some View {
        Group {
            if let metadata {
                LinkPreviewRepresentable(metadata: metadata)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !didFail {
                // Subtle loading placeholder while metadata is in flight.
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(url.host ?? url.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
        }
        .task(id: url) {
            let fetched = await LinkMetadataCache.shared.metadata(for: url)
            if let fetched {
                metadata = fetched
            } else {
                didFail = true
            }
        }
    }
}

// MARK: - NSViewRepresentable

/// Wraps `LPLinkView` for use in SwiftUI on macOS.
private struct LinkPreviewRepresentable: NSViewRepresentable {
    let metadata: LPLinkMetadata

    func makeNSView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        // Prevent the link view from expanding unboundedly.
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: LPLinkView, context: Context) {
        nsView.metadata = metadata
    }
}

// MARK: - Previews

#Preview("Link Preview") {
    VStack(spacing: 12) {
        LinkPreviewView(
            url: URL(string: "https://www.apple.com")!,
            isOutgoing: false
        )
        .frame(width: 300)
        .padding()
        .background(Color(.systemGray).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

        LinkPreviewView(
            url: URL(string: "https://matrix.org")!,
            isOutgoing: true
        )
        .frame(width: 300)
        .padding()
        .background(Color.accentColor)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
    .padding()
}
