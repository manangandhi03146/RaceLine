import SwiftUI
import UIKit

struct SaveRideSheet: View {
    private enum PhotoPickerSource: String, Identifiable {
        case camera
        case library

        var id: String { rawValue }

        var uiKitSourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera:
                return .camera
            case .library:
                return .photoLibrary
            }
        }
    }

    @Binding var name: String
    @Binding var selectedImage: UIImage?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var showPhotoSourceDialog = false
    @State private var photoPickerSource: PhotoPickerSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Name your ride")
                .font(.headline)

            TextField("e.g. Night ride to Rutgers", text: $name)
                .textFieldStyle(.roundedBorder)

            Button {
                showPhotoSourceDialog = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(height: 108)

                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 108)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24, weight: .semibold))
                            Text("Add Ride Photo")
                                .font(.subheadline.weight(.semibold))
                            Text("Take or upload")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack {
                Button("Cancel") { onCancel() }
                    .buttonStyle(.bordered)

                Spacer()

                Button("Save Ride") { onSave() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .confirmationDialog("Ride Photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    photoPickerSource = .camera
                }
            }
            Button("Choose Photo") {
                photoPickerSource = .library
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(item: $photoPickerSource) { source in
            UIKitImagePicker(sourceType: source.uiKitSourceType) { image in
                selectedImage = image
            }
            .ignoresSafeArea()
        }
    }
}

struct UIKitImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: UIKitImagePicker

        init(parent: UIKitImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
    }
}
