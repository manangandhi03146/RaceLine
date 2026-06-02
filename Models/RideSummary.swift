//
//  RideSummary.swift
//  MotorcycleTrackShare
//
//  Created by Manan Gandhi on 1/12/26.
//

import Foundation

struct RideSummary: Codable, Hashable {
    let startTime: Date
    let endTime: Date
    let durationSec: Double
    let distanceM: Double
    let maxSpeedMps: Double
    let maxAbsLeanDeg: Double
    var maxLeanRightDeg: Double    // most leaned right (positive degrees)
    var maxLeanLeftDeg: Double     // most leaned left (positive magnitude)

    var distanceMi: Double { distanceM / 1609.344 }
    var maxSpeedMph: Double { maxSpeedMps * 2.23693629 }

    var durationText: String {
        let s = Int(durationSec)
        return String(format: "%d:%02d:%02d", s/3600, (s%3600)/60, s%60)
    }

    // Backward-compatible decode: old rides missing the lean fields get 0
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startTime       = try c.decode(Date.self,   forKey: .startTime)
        endTime         = try c.decode(Date.self,   forKey: .endTime)
        durationSec     = try c.decode(Double.self, forKey: .durationSec)
        distanceM       = try c.decode(Double.self, forKey: .distanceM)
        maxSpeedMps     = try c.decode(Double.self, forKey: .maxSpeedMps)
        maxAbsLeanDeg   = try c.decode(Double.self, forKey: .maxAbsLeanDeg)
        maxLeanRightDeg = try c.decodeIfPresent(Double.self, forKey: .maxLeanRightDeg) ?? 0
        maxLeanLeftDeg  = try c.decodeIfPresent(Double.self, forKey: .maxLeanLeftDeg)  ?? 0
    }

    init(startTime: Date, endTime: Date, durationSec: Double, distanceM: Double,
         maxSpeedMps: Double, maxAbsLeanDeg: Double,
         maxLeanRightDeg: Double = 0, maxLeanLeftDeg: Double = 0) {
        self.startTime       = startTime
        self.endTime         = endTime
        self.durationSec     = durationSec
        self.distanceM       = distanceM
        self.maxSpeedMps     = maxSpeedMps
        self.maxAbsLeanDeg   = maxAbsLeanDeg
        self.maxLeanRightDeg = maxLeanRightDeg
        self.maxLeanLeftDeg  = maxLeanLeftDeg
    }
}
