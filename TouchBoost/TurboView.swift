import SwiftUI
import UIKit
import CoreHaptics

// MARK: - Motor háptico do Turbo (intensidade + textura ajustáveis)

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

// MARK: - Otimizações do Turbo

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
            reason: "Turbo Gamer"
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
}

extension Notification.Name {
    static let turboStateChanged = Notification.Name("touchboost.turboStateChanged")
}

// MARK: - Sessão de Jogo (FPS ao vivo + boosts ativos)

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

// MARK: - Memória

final class MemoryModel: ObservableObject {
    @Published var currentMB: Double = 0
    @Published var resultText = ""

    func refresh() {
        currentMB = TurboPerf.currentFootprintMB()
    }

    func purge() {
        let r = TurboPerf.purgeMemory()
        resultText = String(format: "%.0f MB → %.0f MB", r.before, r.after)
        refresh()
    }
}

// MARK: - Aba Turbo

struct TurboView: View {
    @AppStorage("boost.turboGamer") private var turboGamer = false
    @AppStorage("boost.preset") private var preset = 2
    @AppStorage("boost.sensitivity") private var sensitivity: Double = 80
    @AppStorage("boost.sharpness") private var sharpness: Double = 70
    @AppStorage("boost.antiDelay") private var antiDelay = true
    @AppStorage("boost.gpuPriority") private var gpuPriority = true
    @AppStorage("boost.processBoost") private var processBoost = true
    @AppStorage("boost.hapticFeedback") private var hapticFeedback = true
    @AppStorage("boost.zeroAnimations") private var zeroAnimations = false
    @AppStorage("boost.immersiveScreen") private var immersiveScreen = false

    @State private var applyStatus = ""
    @State private var appliedAt: Date?

    var body: some View {
        NavigationView {
            Form {
                masterSection
                sensitivitySection
                boostSection
                MemorySection()
                SessionSection()
                applySection
            }
            .navigationTitle("⚡ Turbo")
            .navigationBarTitleDisplayMode(.inline)
            .simultaneousGesture(TapGesture().onEnded {
                if hapticFeedback {
                    TurboHapticsEngine.shared.tap(intensity: Float(sensitivity / 100), sharpness: Float(sharpness / 100))
                }
            })
        }
        .navigationViewStyle(.stack)
    }

    // MARK: Seções

    private var masterSection: some View {
        Section {
            Toggle(isOn: $turboGamer) {
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title)
                        .foregroundColor(turboGamer ? .green : .gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TURBO GAMER")
                            .font(.headline)
                            .foregroundColor(turboGamer ? .green : .primary)
                        Text("Pacote completo com um toque")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)

            Picker("Modo", selection: $preset) {
                Text("Econômico").tag(0)
                Text("Equilibrado").tag(1)
                Text("Máximo").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: preset) { _ in
                applyPreset()
            }
        }
    }

    private var sensitivitySection: some View {
        Section("Sensibilidade do toque") {
            HStack {
                Text("Força")
                Spacer()
                Text("\(Int(sensitivity))%")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundColor(sensitivity >= 70 ? .green : (sensitivity >= 40 ? .yellow : .orange))
            }
            Slider(value: $sensitivity, in: 0...100, step: 5)

            HStack {
                Text("Textura do toque")
                Spacer()
                Text("\(Int(sharpness))%")
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundColor(.blue)
            }
            Slider(value: $sharpness, in: 0...100, step: 5)

            HStack {
                presetButton("Suave", 55, 25)
                presetButton("Precisão", 75, 85)
                presetButton("FPS Rápido", 100, 60)
            }
        }
    }

    private func presetButton(_ title: String, _ s: Double, _ sh: Double) -> some View {
        Button {
            sensitivity = s
            sharpness = sh
            TurboHapticsEngine.shared.tap(intensity: Float(s / 100), sharpness: Float(sh / 100))
        } label: {
            Text(title)
                .font(.footnote.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var boostSection: some View {
        Section("Impulsionar") {
            Toggle(isOn: $antiDelay) {
                Label("Anti-delay", systemImage: "timer")
            }
            .tint(.green)

            Toggle(isOn: $gpuPriority) {
                Label("Prioridade de GPU (120 Hz)", systemImage: "gauge.high")
            }
            .tint(.green)

            Toggle(isOn: $processBoost) {
                Label("Boost de processos", systemImage: "cpu")
            }
            .tint(.green)

            Toggle(isOn: $hapticFeedback) {
                Label("Confirmação háptica", systemImage: "iphone.radiowaves.left.and.right")
            }
            .tint(.green)

            Toggle(isOn: $zeroAnimations) {
                Label("Zero animações", systemImage: "minus.circle")
            }
            .tint(.green)

            Toggle(isOn: $immersiveScreen) {
                Label("Tela imersiva", systemImage: "arrow.up.backward.and.arrow.down.forward")
            }
            .tint(.green)
        }
    }

    private var applySection: some View {
        Section {
            Button {
                applyAll()
            } label: {
                Label("APLICAR OTIMIZAÇÕES AGORA", systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(turboGamer ? .green : .blue)

            if !applyStatus.isEmpty {
                Text(applyStatus)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            if let at = appliedAt {
                Text("Aplicado em \(at, style: .time)")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: Ações

    private func applyPreset() {
        switch preset {
        case 0:
            sensitivity = 45
            sharpness = 30
            antiDelay = false
            gpuPriority = false
            processBoost = false
            zeroAnimations = false
            immersiveScreen = false
        case 1:
            sensitivity = 75
            sharpness = 65
            antiDelay = true
            gpuPriority = false
            processBoost = true
            zeroAnimations = false
            immersiveScreen = false
        default:
            sensitivity = 100
            sharpness = 80
            antiDelay = true
            gpuPriority = true
            processBoost = true
            zeroAnimations = true
            immersiveScreen = true
        }
    }

    private func applyAll() {
        if turboGamer {
            preset = 2
            applyPreset()
        }

        if antiDelay {
            TurboPerf.reduceMainThreadWork()
        } else {
            TurboPerf.allowScreenSleep()
        }

        if gpuPriority {
            TurboPerf.enableHighThroughputMode()
        } else {
            TurboPerf.disableHighThroughputMode()
        }

        if processBoost {
            TurboPerf.enableProcessBoost()
        } else {
            TurboPerf.disableProcessBoost()
        }

        TurboPerf.setZeroAnimations(zeroAnimations)

        if hapticFeedback {
            TurboHapticsEngine.shared.tap(intensity: Float(sensitivity / 100), sharpness: Float(sharpness / 100))
        }

        appliedAt = Date()
        applyStatus = turboGamer
            ? "TURBO GAMER ativo: sensibilidade \(Int(sensitivity))%, 120 Hz, anti-delay, boost de processos e tela sempre acesa."
            : "Ajustes aplicados: sensibilidade \(Int(sensitivity))%, textura \(Int(sharpness))% e boosts selecionados."
    }
}

// MARK: - Seção de memória

struct MemorySection: View {
    @StateObject private var model = MemoryModel()

    var body: some View {
        Section("Memória") {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.blue)
                Text("Em uso (app)")
                Spacer()
                Text(String(format: "%.0f MB", model.currentMB))
                    .font(.subheadline.monospacedDigit().bold())
            }
            Button {
                model.purge()
            } label: {
                Label("Liberar memória agora", systemImage: "wind")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            if !model.resultText.isEmpty {
                Text(model.resultText)
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.green)
            }
        }
        .onAppear { model.refresh() }
    }
}

// MARK: - Seção de sessão de jogo

struct SessionSection: View {
    @StateObject private var session = TurboSessionModel()

    var body: some View {
        Section("Sessão de Jogo") {
            if session.isRunning {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(Int(session.fps))")
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(session.fps >= 100 ? .green : (session.fps >= 55 ? .yellow : .red))
                        Text("FPS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(timeString(session.seconds))
                            .font(.title2.monospacedDigit().bold())
                        Text("tempo de sessão")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Button(role: .destructive) {
                    session.stop()
                } label: {
                    Label("Encerrar sessão", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
            } else {
                Button {
                    session.start()
                } label: {
                    Label("Iniciar sessão com Turbo ativo", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }

    private func timeString(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}
