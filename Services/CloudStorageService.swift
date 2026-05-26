import Foundation
import Supabase
import UIKit

struct CloudStorageService {
    private let client = SupabaseManager.shared.client
    private let bucket = SupabaseConfig.mediaBucket

    func uploadPhoto(_ image: UIImage, path: String) async throws {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw CloudStorageError.compressionFailed
        }
        try await client.storage
            .from(bucket)
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
    }

    func downloadPhoto(path: String) async throws -> UIImage {
        let data = try await client.storage.from(bucket).download(path: path)
        guard let image = UIImage(data: data) else {
            throw CloudStorageError.decodingFailed
        }
        return image
    }

    func createSignedURL(path: String, expiresIn: Int = 3600) async throws -> URL {
        return try await client.storage
            .from(bucket)
            .createSignedURL(path: path, expiresIn: expiresIn)
    }

    func deletePhoto(path: String) async throws {
        try await client.storage.from(bucket).remove(paths: [path])
    }

    enum CloudStorageError: LocalizedError {
        case compressionFailed
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "Failed to compress image for upload."
            case .decodingFailed: return "Failed to decode downloaded image."
            }
        }
    }
}
