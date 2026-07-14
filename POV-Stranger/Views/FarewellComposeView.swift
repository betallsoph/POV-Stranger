import SwiftUI

struct FarewellComposeView: View {
    @Binding var text: String
    let hasSent: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Message in a bottle")
                .font(.headline)

            if hasSent {
                Label("Sent — waiting for the end", systemImage: "paperplane.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("One message. Then you both disappear forever.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Chúc mày một đời bình an…", text: $text, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Text("\(text.count)/280")
                        .font(.caption2)
                        .foregroundStyle(text.count > 280 ? .red : .secondary)

                    Spacer()

                    Button("Send", action: onSend)
                        .buttonStyle(.borderedProminent)
                        .disabled(
                            text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                || text.count > 280
                        )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    @Previewable @State var text = ""
    FarewellComposeView(text: $text, hasSent: false, onSend: {})
        .padding()
}
