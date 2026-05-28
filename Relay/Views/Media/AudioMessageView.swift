// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import QuickLook
import RelayInterface
import SwiftUI
import UniformTypeIdentifiers

/// Renders an audio attachment as a compact bubble with waveform icon, filename,
/// duration, download button, and QuickLook support on double-click.
struct AudioMessageView: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter
    let message: TimelineMessage

    @State private var quickLookURL: URL?
    @State private var isLoadingMedia = false
    @State private var isHovering = false
    @AppStorage("appearance.coloredBubbles") private var coloredBubbles = false

    private var mediaInfo: TimelineMessage.MediaInfo {
        message.mediaInfo!
    }

    private var style: BubbleStyle {
        .message(for: message, coloredBubbles: coloredBubbles)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(style.usesWhiteText ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "waveform")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(style.usesWhiteText ? .white : .accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(mediaInfo.filename)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    if let duration = mediaInfo.duration, duration > 0 {
                        Text(duration.formattedDuration)
                            .font(.caption)
                    }
                    if let size = mediaInfo.size, size > 0 {
                        if mediaInfo.duration != nil && mediaInfo.duration! > 0 {
                            Text("·")
                                .font(.caption)
                        }
                        Text(formatFileSize(size))
                            .font(.caption)
                    }
                }
                .foregroundStyle(style.usesWhiteText ? .white.opacity(0.7) : .secondary)
            }

            Spacer(minLength: 0)

            if isHovering {
                downloadButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 200, maxWidth: 300)
        .background(style.backgroundColor)
        .foregroundStyle(style.usesWhiteText ? .white : .primary)
        .onTapGesture(count: 2) {
            Task { await openQuickLook() }
        }
        .overlay {
            if isLoadingMedia {
                BubbleStyle.shape
                    .fill(.ultraThinMaterial)
                    .overlay { ProgressView() }
            }
        }
        .quickLookPreview($quickLookURL)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    private var downloadButton: some View {
        Button {
            Task { await saveMedia() }
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    style.usesWhiteText ? .white : .primary,
                    style.usesWhiteText ? .white.opacity(0.25) : Color(.systemGray).opacity(0.2)
                )
        }
        .buttonStyle(.plain)
    }

    private func openQuickLook() async {
        guard !isLoadingMedia else { return }
        isLoadingMedia = true
        defer { isLoadingMedia = false }

        do {
            quickLookURL = try await MediaFileHelper.downloadToTemporaryFile(
                mediaInfo: mediaInfo, matrixService: matrixService
            )
        } catch {
            errorReporter.report(.mediaPreviewFailed(filename: mediaInfo.filename, reason: error.localizedDescription))
        }
    }

    private func saveMedia() async {
        do {
            try await MediaFileHelper.saveToFile(
                mediaInfo: mediaInfo, matrixService: matrixService,
                contentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
            )
        } catch {
            errorReporter.report(.mediaSaveFailed(filename: mediaInfo.filename, reason: error.localizedDescription))
        }
    }

    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
