import Foundation
import CoreMotion

@MainActor
final class MotionService: ObservableObject {
    @Published var leanDeg: Double = 0
    @Published var rollRad: Double = 0
    @Published var pitchRad: Double = 0
    @Published var yawRad: Double = 0

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    private var isRunning = false
    private var leanOffsetRad: Double = 0

    var leanSign: Double = 1 // set to -1 if left/right lean is flipped

    func start(hz: Double = 50) {
        guard !isRunning else { return }
        guard manager.isDeviceMotionAvailable else { return }
        isRunning = true

        manager.deviceMotionUpdateInterval = 1.0 / hz

        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let a = m.attitude

            let roll = a.roll
            let pitch = a.pitch
            let yaw = a.yaw

            Task { @MainActor in
                self.rollRad = roll
                self.pitchRad = pitch
                self.yawRad = yaw

                // Stem mount portrait -> lean usually maps to roll
                let rawLean = roll
                self.leanDeg = ((rawLean - self.leanOffsetRad) * self.leanSign) * 180.0 / .pi
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
    }

    func calibrateUpright() {
        // Make current lean read as 0° immediately
        leanOffsetRad = rollRad
        leanDeg = 0
    }
}

