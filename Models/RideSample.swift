//
//  RideSample.swift
//  MotorcycleTrackShare
//
//  Created by Manan Gandhi on 1/12/26.
//
import Foundation

struct RideSample: Codable {
    let t: TimeInterval

    let lat: Double?
    let lon: Double?
    let speedMps: Double?

    let leanDeg: Double?
    let rollRad: Double?
    let pitchRad: Double?
    let yawRad: Double?
}
