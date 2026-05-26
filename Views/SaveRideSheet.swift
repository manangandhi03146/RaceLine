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
    @Binding var selectedBikeID: UUID?
    let bikes: [GarageBike]
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

            Menu {
                Button("No bike") {
                    selectedBikeID = nil
                }
                ForEach(bikes) { bike in
                    Button(bike.title) {
                        selectedBikeID = bike.id
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bike Used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(selectedBikeLabel)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.appSurface2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

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
                                .foregroundStyle(Color.appAccent)
                            Text("Add Ride Photo")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Take or upload")
                                .font(.caption)
                                .foregroundStyle(Color(white: 0.45))
                        }
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

    private var selectedBikeLabel: String {
        guard let selectedBikeID,
              let bike = bikes.first(where: { $0.id == selectedBikeID }) else {
            return "No bike"
        }
        return bike.title
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
