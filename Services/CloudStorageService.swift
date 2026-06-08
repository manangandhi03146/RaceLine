import Foundation
import Supabase
import UIKit

struct CloudStorageService {
    private let client = SupabaseManager.shared.client

    // MARK: - Upload photo to a named bucket

    func uploadPhoto(_ image: UIImage, path: String, bucket: String,
                     compressionQuality: CGFloat = 0.8) async throws {
        guard let data = jpegDataStrippingGPS(image, quality: compressionQuality) else {
            throw CloudStorageError.compressionFailed
        }
        try await client.storage
            .from(bucket)
            .upload(path, data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))
    }

    // MARK: - Download

    func downloadPhoto(path: String, bucket: String) async throws -> UIImage {
        let data = try await client.storage.from(bucket).download(path: path)
        guard let image = UIImage(data: data) else {
            throw CloudStorageError.decodingFailed
        }
        return image
    }

    // MARK: - Signed URL

    func createSignedURL(path: String, bucket: String, expiresIn: Int = 3600) async throws -> URL {
        return try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }

    // MARK: - Delete

    func deleteObject(path: String, bucket: String) async throws {
        try await client.storage.from(bucket).remove(paths: [path])
    }

    // MARK: - Helpers

    private func jpegDataStrippingGPS(_ image: UIImage, quality: CGFloat) -> Data? {
        // Strip GPS EXIF by re-encoding through UIImage (loses metadata)
        return image.jpegData(compressionQuality: quality)
    }

    enum CloudStorageError: LocalizedError {
        case compressionFailed
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "Failed to compress image for upload."
            case .decodingFailed:    return "Failed to decode downloaded image."
            }
        }
    }
}
