import Foundation

struct RideSample: Codable {
    let t: TimeInterval

    let lat: Double?
    let lon: Double?
    let speedMps: Double?
    let altitudeM: Double?

    let leanDeg: Double?
    let rollRad: Double?
    let pitchRad: Double?
    let yawRad: Double?

    // Acceleration (m/s²) — positive = forward, negative = braking
    let accelX: Double?     // lateral
    let accelY: Double?     // longitudinal (forward/back)
    let accelZ: Double?     // vertical
}
