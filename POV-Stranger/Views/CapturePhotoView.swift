import SwiftUI
import UIKit

struct CapturePhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void

    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var selectedImage: UIImage?
    @State private var safetyError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                } else {
                    ContentUnavailableView(
                        "Share this hour",
                        systemImage: "camera.viewfinder",
                        description: Text("Capture what your stranger will see from your world.")
                    )
                }

                HStack(spacing: 16) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingLibrary = true
                    } label: {
                        Label("Library", systemImage: "photo.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                if selectedImage != nil {
                    Button("Send this hour") {
                        sendPhoto()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Hour \(hourLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    selectedImage = image
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    selectedImage = image
                }
                .ignoresSafeArea()
            }
            .alert("Can't share this photo", isPresented: .init(
                get: { safetyError != nil },
                set: { if !$0 { safetyError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(safetyError ?? "")
            }
        }
    }

    private var hourLabel: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return "\(hour + 1)"
    }

    private func sendPhoto() {
        guard let selectedImage,
              let data = PhotoCompressor.compress(selectedImage) else { return }

        Task {
            do {
                try await ContentSafetyChecker.validate(selectedImage)
                onCapture(data)
                dismiss()
            } catch {
                safetyError = error.localizedDescription
            }
        }
    }
}

private struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    CapturePhotoView { _ in }
}
