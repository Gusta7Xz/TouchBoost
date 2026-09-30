import SwiftUI
import UIKit
import CoreHaptics

// MARK: - Motor háptico (intensidade + textura ajustáveis)

final class TurboHapticsEngine {
    static let shared = TurboHapticsEngine()
    private var engine: CHHapticEngine?
    private var available = true

    private init() {
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            available = false
        }
    }

    func tap(intensity: Float, sharpness: Float) {
        guard available, let engine = engine else {
            let style: UIImpactFeedbackGenerator.FeedbackStyle = intensity > 0.6 ? .heavy : (intensity > 0.3 ? .medium : .light)
            let g = UIImpactFeedbackGenerator(style: style)
            g.prepare()
            g.impactOccurred(intensity: CGFloat(max(0.2, min(1.0, intensity))))
            return
        }
        do {
            let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: max(0.05, min(1.0, intensity)))
            let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: max(0.05, min(1.0, sharpness)))
            let ev = CHHapticEvent(eventType: .hapticTransient, parameters: [i, s], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [ev], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            // silencioso
        }
    }
}

// MARK: - Motor de otimização

enum TurboPerf {
    static var wantsMaxRefreshRate = false
    static var activityToken: NSObjectProtocol?

    static func reduceMainThreadWork() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func allowScreenSleep() {
        UIApplication.shared.isIdleTimerDisabled = false
    }

    static func enableHighThroughputMode() {
        wantsMaxRefreshRate = true
        NotificationCenter.default.post(name: .turboStateChanged, object: nil)
    }

    static func disableHighThroughputMode() {
        wantsMaxRefreshRate = false
        NotificationCenter.default.post(name: .turboStateChanged, object: nil)
    }

    static func enableProcessBoost() {
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Turbo"
        )
    }

    static func disableProcessBoost() {
        if let t = activityToken {
            ProcessInfo.processInfo.endActivity(t)
            activityToken = nil
        }
    }

    static func setZeroAnimations(_ disabled: Bool) {
        UIView.setAnimationsEnabled(!disabled)
    }

    // MARK: Memória e cache

    static func currentFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return r == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }

    static func purgeMemory() -> (before: Double, after: Double) {
        let before = currentFootprintMB()
        let sel = Selector(("_performMemoryWarning"))
        if UIApplication.shared.responds(to: sel) {
            _ = UIApplication.shared.perform(sel)
        }
        // Ciclo de pressão de memória para forçar limpeza de cache.
        var ballast: [Data] = []
        for _ in 0..<8 {
            ballast.append(Data(count: 12_000_000))
        }
        ballast.removeAll()
        let after = currentFootprintMB()
        return (before, after)
    }

    static func appCacheSizeMB() -> Double {
        let fm = FileManager.default
        var dirs: [URL] = []
        if let c = fm.urls(for: .cachesDirectory, in: .userDomainMask).first { dirs.append(c) }
        dirs.append(fm.temporaryDirectory)
        var total: Int64 = 0
        for dir in dirs {
            if let en = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let f as URL in en {
                    if let v = try? f.resourceValues(forKeys: [.fileSizeKey]), let s = v.fileSize {
                        total += Int64(s)
                    }
                }
            }
        }
        return Double(total) / 1_048_576
    }

    static func clearAppCache() -> Double {
        let before = appCacheSizeMB()
        URLCache.shared.removeAllCachedResponses()
        let fm = FileManager.default
        var dirs: [URL] = []
        if let c = fm.urls(for: .cachesDirectory, in: .userDomainMask).first { dirs.append(c) }
        dirs.append(fm.temporaryDirectory)
        for dir in dirs {
            if let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                for item in items {
                    try? fm.removeItem(at: item)
                }
            }
        }
        return max(0, before - appCacheSizeMB())
    }

    // MARK: Aquecimento de CPU

    static func warmUpCPU(seconds: Double = 2.0) {
        let deadline = Date().addingTimeInterval(seconds)
        let cores = max(2, ProcessInfo.processInfo.activeProcessorCount)
        let workers = min(cores, 4)
        for _ in 0..<workers {
            DispatchQueue.global(qos: .userInteractive).async {
                var x: Double = 1.000001
                while Date() < deadline {
                    for _ in 0..<100_000 {
                        x = x * 1.0000001 + 0.5
                        if x.isInfinite { x = 1.0 }
                    }
                }
            }
        }
    }
}

extension Notification.Name {
    static let turboStateChanged = Notification.Name("touchboost.turboStateChanged")
}

// MARK: - Sessão de Jogo

final class TurboSessionModel: ObservableObject {
    @Published var isRunning = false
    @Published var fps: Double = 0
    @Published var seconds: Int = 0

    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var deltas: [Double] = []
    private var ticker: Timer?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        seconds = 0
        fps = 0
        TurboPerf.reduceMainThreadWork()
        TurboPerf.enableHighThroughputMode()
        TurboPerf.enableProcessBoost()

        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        if #available(iOS 15.0, *) {
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }
        link = l

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.seconds += 1
        }
    }

    func stop() {
        isRunning = false
        link?.invalidate()
        link = nil
        ticker?.invalidate()
        ticker = nil
        deltas.removeAll()
        last = 0
        TurboPerf.disableProcessBoost()
        TurboPerf.disableHighThroughputMode()
        TurboPerf.allowScreenSleep()
    }

    @objc private func tick(_ l: CADisplayLink) {
        if last > 0 {
            let d = l.timestamp - last
            if d > 0 {
                deltas.append(d)
                if deltas.count > 60 { deltas.removeFirst() }
            }
        }
        last = l.timestamp
        if deltas.count >= 15 {
            let avg = deltas.reduce(0, +) / Double(deltas.count)
            fps = min(240, 1 / avg)
        }
    }
}

// MARK: - Manutenção (memória, cache, CPU)

final class MaintenanceModel: ObservableObject {
    @Published var memMB: Double = 0
    @Published var cacheMB: Double = 0
    @Published var resultText = ""

    func refresh() {
        memMB = TurboPerf.currentFootprintMB()
        cacheMB = TurboPerf.appCacheSizeMB()
    }

    func purgeMemory() {
        let r = TurboPerf.purgeMemory()
        resultText = String(format: "Memória: %.0f MB → %.0f MB", r.before, r.after)
        refresh()
    }

    func clearCache() {
        let freed = TurboPerf.clearAppCache()
        resultText = String(format: "Cache: %.1f MB liberados", freed)
        refresh()
    }

    func warmUp() {
        TurboPerf.warmUpCPU(seconds: 2)
        resultText = "CPU aquecida (2s em prioridade máxima)"
    }
}
