import SwiftUI
import UIKit

struct SaveRideSheet: View {
    private enum PhotoPickerSource: String, Identifiable {
        case camera
        case library
        var id: String { rawValue }
        var uiKitSourceType: UIImagePickerController.SourceType {
            self == .camera ? .camera : .photoLibrary
        }
    }

    @Binding var name: String
    @Binding var selectedImage: UIImage?
    @Binding var selectedBikeID: UUID?
    @Binding var selectedRideType: RideType
    @Binding var selectedStorageMode: StorageMode
    @Binding var notes: String
    @Binding var tags: [String]

    let bikes: [GarageBike]
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var tagsText: String = ""
    @State private var showPhotoSourceDialog = false
    @State private var photoPickerSource: PhotoPickerSource?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Save Ride")
                    .font(.headline)
                    .padding(.top, 4)

                // Name
                TextField("Ride name (optional)", text: $name)
                    .textFieldStyle(.roundedBorder)

                // Ride type
                Picker("Ride Type", selection: $selectedRideType) {
                    ForEach(RideType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                if selectedRideType == .track {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        Text("Track mode is not a lap timer or official timing device.")
                            .font(.caption)
                            .foregroundStyle(Color.textSecondary)
                    }
                }

                // Bike
                Menu {
                    Button("No bike") { selectedBikeID = nil }
                    ForEach(bikes) { bike in
                        Button(bike.title) { selectedBikeID = bike.id }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bike Used")
                                .font(.caption)
                                .foregroundStyle(Color.textSecondary)
                            Text(selectedBikeLabel)
                                .foregroundStyle(Color.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.appSurface2)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Storage mode
                Picker("Storage", selection: $selectedStorageMode) {
                    Text("Phone Only").tag(StorageMode.localOnly)
                    Text("Cloud Summary").tag(StorageMode.cloudSummaryOnly)
                    Text("Cloud Full Data").tag(StorageMode.cloudFull)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Notes
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes (optional)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    TextField("Anything to note about this ride…", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .textFieldStyle(.roundedBorder)
                }

                // Tags
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags (comma separated)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                    TextField("canyon, commute, twisties…", text: $tagsText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: tagsText) { _, val in
                            tags = val
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                                .filter { !$0.isEmpty }
                        }
                }

                // Photo
                Button { showPhotoSourceDialog = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 100)
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(Color.appAccent)
                                Text("Add Ride Photo (optional)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
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
                        .tint(Color.appAccent)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .confirmationDialog("Ride Photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { photoPickerSource = .camera }
            }
            Button("Choose Photo") { photoPickerSource = .library }
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

// MARK: - UIKitImagePicker

struct UIKitImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: UIKitImagePicker
        init(parent: UIKitImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onImagePicked(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
