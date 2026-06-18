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
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                AppSheetHeader(
                    title: "Save Ride",
                    onCancel: onCancel,
                    saveLabel: "Save Ride",
                    onSave: onSave
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        AppFieldGroup(label: "NAME (OPTIONAL)") {
                            TextField("", text: $name, prompt: .appPrompt("Untitled ride"))
                                .foregroundStyle(Color.textPrimary)
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "BIKE USED") {
                            Menu {
                                Button("No bike") { selectedBikeID = nil }
                                ForEach(bikes) { bike in
                                    Button(bike.title) { selectedBikeID = bike.id }
                                }
                            } label: {
                                HStack {
                                    Text(selectedBikeLabel)
                                        .foregroundStyle(Color.textPrimary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .appFieldChrome()
                            }
                        }

                        AppFieldGroup(label: "STORAGE") {
                            Menu {
                                Button("Phone Only") { selectedStorageMode = .localOnly }
                                Button("Cloud Summary") { selectedStorageMode = .cloudSummaryOnly }
                                Button("Cloud Full Data") { selectedStorageMode = .cloudFull }
                            } label: {
                                HStack {
                                    Text(storageModeLabel)
                                        .foregroundStyle(Color.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.textSecondary)
                                }
                                .appFieldChrome()
                            }
                        }

                        AppFieldGroup(label: "NOTES (OPTIONAL)") {
                            TextField("", text: $notes, prompt: .appPrompt("Anything to note about this ride…"), axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .foregroundStyle(Color.textPrimary)
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "TAGS (COMMA SEPARATED)") {
                            TextField("", text: $tagsText, prompt: .appPrompt("canyon, commute, twisties…"))
                                .foregroundStyle(Color.textPrimary)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: tagsText) { _, val in
                                    tags = val
                                        .split(separator: ",")
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                                        .filter { !$0.isEmpty }
                                }
                                .appFieldChrome()
                        }

                        AppFieldGroup(label: "RIDE PHOTO (OPTIONAL)") {
                            Button { showPhotoSourceDialog = true } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.appSurface2)
                                        .frame(height: 110)
                                    if let selectedImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 110)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        VStack(spacing: 6) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 22, weight: .semibold))
                                                .foregroundStyle(Color.appAccent)
                                            Text("Add Ride Photo")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(Color.textPrimary)
                                        }
                                    }
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
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

    private var storageModeLabel: String {
        selectedStorageMode.displayName
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
