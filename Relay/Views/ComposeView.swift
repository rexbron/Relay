import SwiftUI
import UniformTypeIdentifiers

struct ComposeView: View {
    @Binding var text: String
    var onSend: () -> Void
    var onAttach: ([URL]) -> Void

    @FocusState private var isFocused: Bool
    @State private var isShowingFilePicker = false

    var body: some View {
        GlassEffectContainer {
            HStack(alignment: .center, spacing: 8) {
                Button { isShowingFilePicker = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                        .glassEffect(in: .circle)
                }
                .buttonStyle(.plain)

                TextField("Message", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect()
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.image, .movie, .item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result, !urls.isEmpty {
                onAttach(urls)
            }
        }
    }
}

#Preview("Empty") {
    ComposeView(text: .constant(""), onSend: {}, onAttach: { _ in })
        .frame(width: 400)
}

#Preview("With Text") {
    ComposeView(text: .constant("Hello, world!"), onSend: {}, onAttach: { _ in })
        .frame(width: 400)
}
