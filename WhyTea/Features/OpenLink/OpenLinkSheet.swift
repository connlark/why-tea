import SwiftUI
import WhyTeaYouTube

struct OpenLinkSheet: View {
    let onOpen: (VideoID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(text: String = "", onOpen: @escaping (VideoID) -> Void) {
        self.onOpen = onOpen
        self.text = text
    }

    private var videoID: VideoID? { VideoID(parsing: text) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Link or video ID", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(open)
                    PasteButton(payloadType: String.self, onPaste: paste)
                } footer: {
                    if !text.isEmpty, videoID == nil {
                        Text("That doesn't look like a YouTube video link.")
                    }
                }
            }
            .navigationTitle("Open Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel, action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm, action: open)
                        .disabled(videoID == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func paste(_ strings: [String]) {
        guard let pasted = strings.first else { return }
        text = pasted
        open()
    }

    private func open() {
        guard let videoID else { return }
        onOpen(videoID)
    }

    private func cancel() {
        dismiss()
    }
}

#Preview {
    OpenLinkSheet { _ in }
}
