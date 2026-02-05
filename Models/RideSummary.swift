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

    var distanceMi: Double { distanceM / 1609.344 }
    var maxSpeedMph: Double { maxSpeedMps * 2.23693629 }

    var durationText: String {
        let s = Int(durationSec)
        return String(format: "%d:%02d:%02d", s/3600, (s%3600)/60, s%60)
    }
}
