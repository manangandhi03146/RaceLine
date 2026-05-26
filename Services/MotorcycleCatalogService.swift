import Foundation

struct MotorcycleMakeOption: Identifiable, Hashable {
    let id: Int
    let name: String
}

struct MotorcycleModelOption: Identifiable, Hashable {
    let id: Int
    let name: String
}

@MainActor
final class MotorcycleCatalogService: ObservableObject {
    @Published private(set) var makes: [MotorcycleMakeOption] = []
    @Published private(set) var models: [MotorcycleModelOption] = []
    @Published private(set) var isLoadingMakes = false
    @Published private(set) var isLoadingModels = false
    @Published private(set) var makesErrorMessage: String?
    @Published private(set) var modelsErrorMessage: String?

    private var didLoadMakes = false
    private var modelCache: [String: [MotorcycleModelOption]] = [:]

    func loadMakesIfNeeded() async {
        guard !didLoadMakes, !isLoadingMakes else { return }
        await loadMakes()
    }

    func loadModels(makeName: String, year: Int?) async {
        let trimmedMake = makeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMake.isEmpty else {
            models = []
            modelsErrorMessage = nil
            return
        }

        let cacheKey = "\(trimmedMake.lowercased())-\(year.map(String.init) ?? "all")"
        if let cached = modelCache[cacheKey] {
            models = cached
            modelsErrorMessage = nil
            return
        }

        isLoadingModels = true
        modelsErrorMessage = nil

        do {
            let endpoint: String
            if let year, year > 1995 {
                endpoint = "https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/\(encodePathSegment(trimmedMake))/modelyear/\(year)/vehicletype/motorcycle?format=json"
            } else {
                endpoint = "https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMake/\(encodePathSegment(trimmedMake))?format=json"
            }

            let (data, _) = try await URLSession.shared.data(from: URL(string: endpoint)!)
            let decoded = try JSONDecoder().decode(VPICResponse<VPICModelResult>.self, from: data)

            let unique = Dictionary(grouping: decoded.results) { $0.id }
                .compactMap { _, values in values.first }
                .map { MotorcycleModelOption(id: $0.id, name: $0.name) }
                .sorted { $0.name < $1.name }

            modelCache[cacheKey] = unique
            models = unique
        } catch {
            models = []
            modelsErrorMessage = "Could not load motorcycle models."
        }

        isLoadingModels = false
    }

    private func loadMakes() async {
        isLoadingMakes = true
        makesErrorMessage = nil

        do {
            let endpoint = "https://vpic.nhtsa.dot.gov/api/vehicles/GetMakesForVehicleType/motorcycle?format=json"
            let (data, _) = try await URLSession.shared.data(from: URL(string: endpoint)!)
            let decoded = try JSONDecoder().decode(VPICResponse<VPICMakeResult>.self, from: data)

            makes = Dictionary(grouping: decoded.results) { $0.id }
                .compactMap { _, values in values.first }
                .map { MotorcycleMakeOption(id: $0.id, name: $0.name) }
                .sorted { $0.name < $1.name }

            didLoadMakes = true
        } catch {
            makes = []
            makesErrorMessage = "Could not load motorcycle makes."
        }

        isLoadingMakes = false
    }

    private func encodePathSegment(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? text
    }
}

private struct VPICResponse<ResultType: Decodable>: Decodable {
    let results: [ResultType]

    enum CodingKeys: String, CodingKey {
        case results = "Results"
    }
}

private struct VPICMakeResult: Decodable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "MakeId"
        case name = "MakeName"
    }
}

private struct VPICModelResult: Decodable {
    let id: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Model_ID"
        case name = "Model_Name"
    }
}
