import Foundation

struct RideSummary: Codable, Hashable {
    let startTime: Date
    let endTime: Date
    let durationSec: Double
    let distanceM: Double
    let maxSpeedMps: Double
    let maxAbsLeanDeg: Double
    var maxLeanRightDeg: Double
    var maxLeanLeftDeg: Double

    // Extended stats — optional for backward compatibility
    var avgSpeedMps: Double?
    var elevationGainM: Double?
    var minAltitudeM: Double?
    var maxAltitudeM: Double?
    var hardBrakingCount: Int?
    var aggressiveAccelCount: Int?

    // Convenience
    var distanceMi: Double { distanceM / 1609.344 }
    var maxSpeedMph: Double { maxSpeedMps * 2.23693629 }
    var avgSpeedMph: Double? { avgSpeedMps.map { $0 * 2.23693629 } }

    var computedAvgSpeedMph: Double {
        guard durationSec > 0 else { return 0 }
        return (distanceM / durationSec) * 2.23693629
    }

    var durationText: String {
        let s = Int(durationSec)
        return String(format: "%d:%02d:%02d", s/3600, (s%3600)/60, s%60)
    }

    // Backward-compatible decode: old rides missing fields get nil/0
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let startRaw = try c.decode(Double.self, forKey: .startTime)
        startTime = startRaw >= 978_307_200
            ? Date(timeIntervalSince1970: startRaw)
            : Date(timeIntervalSinceReferenceDate: startRaw)
        let endRaw = try c.decode(Double.self, forKey: .endTime)
        endTime = endRaw >= 978_307_200
            ? Date(timeIntervalSince1970: endRaw)
            : Date(timeIntervalSinceReferenceDate: endRaw)
        durationSec         = try c.decode(Double.self, forKey: .durationSec)
        distanceM           = try c.decode(Double.self, forKey: .distanceM)
        maxSpeedMps         = try c.decode(Double.self, forKey: .maxSpeedMps)
        maxAbsLeanDeg       = try c.decode(Double.self, forKey: .maxAbsLeanDeg)
        maxLeanRightDeg     = try c.decodeIfPresent(Double.self, forKey: .maxLeanRightDeg) ?? 0
        maxLeanLeftDeg      = try c.decodeIfPresent(Double.self, forKey: .maxLeanLeftDeg)  ?? 0
        avgSpeedMps         = try c.decodeIfPresent(Double.self, forKey: .avgSpeedMps)
        elevationGainM      = try c.decodeIfPresent(Double.self, forKey: .elevationGainM)
        minAltitudeM        = try c.decodeIfPresent(Double.self, forKey: .minAltitudeM)
        maxAltitudeM        = try c.decodeIfPresent(Double.self, forKey: .maxAltitudeM)
        hardBrakingCount    = try c.decodeIfPresent(Int.self, forKey: .hardBrakingCount)
        aggressiveAccelCount = try c.decodeIfPresent(Int.self, forKey: .aggressiveAccelCount)
    }

    init(startTime: Date, endTime: Date, durationSec: Double, distanceM: Double,
         maxSpeedMps: Double, maxAbsLeanDeg: Double,
         maxLeanRightDeg: Double = 0, maxLeanLeftDeg: Double = 0,
         avgSpeedMps: Double? = nil,
         elevationGainM: Double? = nil, minAltitudeM: Double? = nil, maxAltitudeM: Double? = nil,
         hardBrakingCount: Int? = nil, aggressiveAccelCount: Int? = nil) {
        self.startTime           = startTime
        self.endTime             = endTime
        self.durationSec         = durationSec
        self.distanceM           = distanceM
        self.maxSpeedMps         = maxSpeedMps
        self.maxAbsLeanDeg       = maxAbsLeanDeg
        self.maxLeanRightDeg     = maxLeanRightDeg
        self.maxLeanLeftDeg      = maxLeanLeftDeg
        self.avgSpeedMps         = avgSpeedMps
        self.elevationGainM      = elevationGainM
        self.minAltitudeM        = minAltitudeM
        self.maxAltitudeM        = maxAltitudeM
        self.hardBrakingCount    = hardBrakingCount
        self.aggressiveAccelCount = aggressiveAccelCount
    }
}
