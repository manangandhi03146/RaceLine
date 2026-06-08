import Foundation
import CoreLocation

@MainActor
final class RideRecorder: ObservableObject {
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var fileURL: URL?
    @Published private(set) var summary: RideSummary?
    @Published private(set) var route: [RidePoint] = []
    @Published private(set) var liveMaxAbsLeanDeg: Double = 0

    private var samples: [RideSample] = []
    private var recordingTask: Task<Void, Never>?

    private var startTime: Date?
    private var distanceM: Double = 0
    private var lastCoord: (lat: Double, lon: Double)?

    // Altitude tracking
    private var altitudes: [Double] = []
    private var elevationGainM: Double = 0
    private var lastAltitude: Double?

    // Hard braking / aggressive acceleration detection
    private var hardBrakingCount: Int = 0
    private var aggressiveAccelCount: Int = 0
    private var lastSpeedMps: Double?
    private var lastSampleTime: TimeInterval?

    // Keep references so the Task only captures `self`
    private weak var motionService: MotionService?
    private weak var locationService: LocationService?

    func start(motion: MotionService, location: LocationService, sampleHz: Double = 10) {
        guard !isRecording else { return }

        isRecording = true
        fileURL = nil
        summary = nil
        samples.removeAll()
        route.removeAll()
        liveMaxAbsLeanDeg = 0

        startTime = Date()
        distanceM = 0
        lastCoord = nil
        altitudes.removeAll()
        elevationGainM = 0
        lastAltitude = nil
        hardBrakingCount = 0
        aggressiveAccelCount = 0
        lastSpeedMps = nil
        lastSampleTime = nil

        motionService = motion
        locationService = location

        recordingTask?.cancel()

        let hz = max(1.0, min(sampleHz, 50.0))
        let intervalNs = UInt64(1_000_000_000 / hz)

        recordingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await MainActor.run { self.captureSample() }
                try? await Task.sleep(nanoseconds: intervalNs)
            }
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false

        recordingTask?.cancel()
        recordingTask = nil

        let end = Date()
        let start = startTime ?? end

        let leanValues  = samples.compactMap { $0.leanDeg }
        let maxSpeed    = samples.compactMap { $0.speedMps }.max() ?? 0
        let maxLean     = leanValues.map { abs($0) }.max() ?? 0
        let maxRight    = leanValues.filter { $0 > 0 }.max() ?? 0
        let maxLeft     = leanValues.filter { $0 < 0 }.map { abs($0) }.max() ?? 0

        let duration    = end.timeIntervalSince(start)
        let avgSpeedMps = duration > 0 ? distanceM / duration : 0

        summary = RideSummary(
            startTime:            start,
            endTime:              end,
            durationSec:          duration,
            distanceM:            distanceM,
            maxSpeedMps:          maxSpeed,
            maxAbsLeanDeg:        maxLean,
            maxLeanRightDeg:      maxRight,
            maxLeanLeftDeg:       maxLeft,
            avgSpeedMps:          avgSpeedMps,
            elevationGainM:       elevationGainM > 0 ? elevationGainM : nil,
            minAltitudeM:         altitudes.min(),
            maxAltitudeM:         altitudes.max(),
            hardBrakingCount:     hardBrakingCount > 0 ? hardBrakingCount : nil,
            aggressiveAccelCount: aggressiveAccelCount > 0 ? aggressiveAccelCount : nil
        )

        do {
            fileURL = try writeJSONLines(samples: samples)
        } catch {
            print("RideRecorder: Failed to write ride file:", error)
        }

        motionService = nil
        locationService = nil
    }

    // MARK: - Internal sampling

    private func captureSample() {
        guard let motion = motionService, let location = locationService else { return }

        let now = Date().timeIntervalSince1970

        // GPS + distance + route
        if let lat = location.lat, let lon = location.lon {
            if let last = lastCoord {
                let segment = haversineMeters(lat1: last.lat, lon1: last.lon, lat2: lat, lon2: lon)
                if segment.isFinite && segment >= 0 && segment < 250 {
                    distanceM += segment
                    if segment > 3 {
                        route.append(RidePoint(lat: lat, lon: lon))
                    }
                }
            } else {
                route.append(RidePoint(lat: lat, lon: lon))
            }
            lastCoord = (lat, lon)
        }

        // Altitude / elevation gain
        if let alt = location.altitudeM {
            altitudes.append(alt)
            if let prev = lastAltitude {
                let delta = alt - prev
                if delta > 0 {
                    elevationGainM += delta
                }
            }
            lastAltitude = alt
        }

        // Hard braking / aggressive acceleration detection
        if let currentSpeed = location.speedMps, let prevSpeed = lastSpeedMps,
           let prevTime = lastSampleTime {
            let dt = now - prevTime
            if dt > 0 {
                let accel = (currentSpeed - prevSpeed) / dt
                if accel < -4.0 { hardBrakingCount += 1 }       // > 0.4g braking
                if accel > 3.0  { aggressiveAccelCount += 1 }   // > 0.3g acceleration
            }
        }

        if let spd = location.speedMps { lastSpeedMps = spd }
        lastSampleTime = now

        // Max lean
        let absLean = abs(motion.leanDeg)
        if absLean > liveMaxAbsLeanDeg { liveMaxAbsLeanDeg = absLean }

        let s = RideSample(
            t:        now,
            lat:      location.lat,
            lon:      location.lon,
            speedMps: location.speedMps,
            altitudeM: location.altitudeM,
            leanDeg:  motion.leanDeg,
            rollRad:  motion.rollRad,
            pitchRad: motion.pitchRad,
            yawRad:   motion.yawRad,
            accelX:   motion.accelX,
            accelY:   motion.accelY,
            accelZ:   motion.accelZ
        )

        samples.append(s)
    }

    // MARK: - File export

    private func writeJSONLines(samples: [RideSample]) throws -> URL {
        let encoder = JSONEncoder()
        var out = ""
        out.reserveCapacity(samples.count * 150)
        for s in samples {
            let data = try encoder.encode(s)
            out += String(decoding: data, as: UTF8.self)
            out += "\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ride-\(Int(Date().timeIntervalSince1970)).jsonl")
        try out.data(using: .utf8)!.write(to: url, options: [.atomic])
        return url
    }

    // MARK: - Distance math

    private func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0)
              * sin(dLon / 2) * sin(dLon / 2)
        return 2.0 * r * atan2(sqrt(a), sqrt(1.0 - a))
    }
}
