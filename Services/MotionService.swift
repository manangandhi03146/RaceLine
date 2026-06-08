import Foundation
import CoreMotion

@MainActor
final class MotionService: ObservableObject {
    @Published var leanDeg: Double = 0
    @Published var rollRad: Double = 0
    @Published var pitchRad: Double = 0
    @Published var yawRad: Double = 0
    @Published var accelX: Double = 0   // lateral
    @Published var accelY: Double = 0   // longitudinal (forward/back)
    @Published var accelZ: Double = 0   // vertical

    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    private var isRunning = false
    private var leanOffsetRad: Double = 0

    var leanSign: Double = 1

    func start(hz: Double = 50) {
        guard !isRunning else { return }
        guard manager.isDeviceMotionAvailable else { return }
        isRunning = true

        manager.deviceMotionUpdateInterval = 1.0 / hz

        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let a = m.attitude
            let ua = m.userAcceleration

            Task { @MainActor in
                self.rollRad  = a.roll
                self.pitchRad = a.pitch
                self.yawRad   = a.yaw
                self.accelX   = ua.x
                self.accelY   = ua.y
                self.accelZ   = ua.z

                let rawLean = a.roll
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
        leanOffsetRad = rollRad
        leanDeg = 0
    }
}
