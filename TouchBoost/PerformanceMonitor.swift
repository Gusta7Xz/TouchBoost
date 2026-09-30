import SwiftUI
import UIKit

final class PerformanceModel: ObservableObject {
    @Published var fps: Double = 0
    @Published var frameTimeMs: Double = 0
    @Published var maxObservedFPS: Double = 0
    @Published var memoryFootprintMB: Double = 0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published var fpsHistory: [Double] = []

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameDeltas: [Double] = []
    private var thermalObserver: NSObjectProtocol?
    private var powerObserver: NSObjectProtocol?
    private var turboObserver: NSObjectProtocol?

    var thermalLabel: String {
        switch thermalState {
        case .nominal: return "Nominal (frio)"
        case .fair: return "Justa"
        case .serious: return "Séria ⚠️"
        case .critical: return "Crítica 🔥"
        @unknown default: return "Desconhecida"
        }
    }

    var thermalColor: Color {
        switch thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        applyFrameRateRange(to: link)
        displayLink = link

        // Turbo: reaplica o range quando o modo Turbo liga/desliga.
        turboObserver = NotificationCenter.default.addObserver(
            forName: .turboStateChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let link = self?.displayLink else { return }
            self?.applyFrameRateRange(to: link)
        }

        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
        }
        powerObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        thermalState = ProcessInfo.processInfo.thermalState
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        if let o = thermalObserver { NotificationCenter.default.removeObserver(o) }
        if let o = powerObserver { NotificationCenter.default.removeObserver(o) }
        if let o = turboObserver { NotificationCenter.default.removeObserver(o) }
        thermalObserver = nil
        powerObserver = nil
        turboObserver = nil
    }

    /// Pede 120 Hz quando o Turbo está ativo; senão deixa o sistema decidir.
    private func applyFrameRateRange(to link: CADisplayLink) {
        if TurboPerf.wantsMaxRefreshRate {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        } else {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        }
    }

    @objc private func step(_ link: CADisplayLink) {
        if lastTimestamp > 0 {
            let delta = link.timestamp - lastTimestamp
            if delta > 0 {
                frameDeltas.append(delta)
                if frameDeltas.count > 120 { frameDeltas.removeFirst(frameDeltas.count - 120) }
            }
        }
        lastTimestamp = link.timestamp

        // Atualiza UI ~2x por segundo para não pesar a própria medição.
        if frameDeltas.count >= 30 {
            let avgDelta = frameDeltas.reduce(0, +) / Double(frameDeltas.count)
            let currentFPS = min(1.0 / avgDelta, 240)
            fps = currentFPS
            frameTimeMs = avgDelta * 1000
            maxObservedFPS = max(maxObservedFPS, currentFPS)
            fpsHistory.append(currentFPS)
            if fpsHistory.count > 120 { fpsHistory.removeFirst(fpsHistory.count - 120) }
        }
        memoryFootprintMB = Double(Self.currentMemoryFootprint()) / 1_048_576
    }

    /// Pegada real de memória (phys_footprint), igual ao que o Xcode mostra.
    static func currentMemoryFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}

struct PerformanceMonitorView: View {
    @StateObject private var model = PerformanceModel()

    var body: some View {
        TBScreen {
            TBHero(
                title: "DESEMPENHO",
                subtitle: "FPS, memória e temperatura ao vivo",
                systemImage: "gauge.high",
                stat1: ("\(Int(model.fps))", "FPS agora"),
                stat2: ("\(Int(model.maxObservedFPS))", "FPS máx"),
                stat3: (String(format: "%.0f", model.memoryFootprintMB), "MB em uso")
            )
            .onAppear { model.start() }
            .onDisappear { model.stop() }

            TBSectionHeader(title: "Taxa de Quadros")

            TBCard {
                VStack(spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(model.fps))")
                            .font(.system(size: 58, weight: .heavy, design: .rounded))
                            .foregroundColor(model.fps >= 100 ? TBTheme.accent : (model.fps >= 55 ? .yellow : .red))
                        Text("FPS")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("quadro: \(model.frameTimeMs, specifier: "%.1f") ms")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                            Text("pico: \(Int(model.maxObservedFPS)) FPS")
                                .font(.caption.monospacedDigit().bold())
                                .foregroundColor(TBTheme.accent)
                        }
                    }

                    GeometryReader { geo in
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(Array(model.fpsHistory.enumerated()), id: \.offset) { _, value in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(value >= 100 ? TBTheme.accent : (value >= 55 ? Color.yellow : Color.red))
                                    .frame(height: max(3, CGFloat(value / 120) * geo.size.height))
                            }
                        }
                    }
                    .frame(height: 56)
                }
            }

            TBSectionHeader(title: "Sistema")

            TBCard {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        systemRow("memorychip", "Memória", String(format: "%.0f MB", model.memoryFootprintMB), .blue)
                        systemRow("thermometer.medium", "Térmico", model.thermalLabel, model.thermalColor)
                    }
                    HStack(spacing: 12) {
                        systemRow(model.lowPowerMode ? "battery.25" : "battery.100", "Pouca Energia", model.lowPowerMode ? "ATIVO" : "Inativo", model.lowPowerMode ? .orange : TBTheme.accent)
                        systemRow("cpu", "Processador", "arm64", .purple)
                    }
                }
            }

            TBSectionHeader(title: "Leitura dos Dados")

            TBCard {
                VStack(alignment: .leading, spacing: 8) {
                    bullet("Quedas de FPS com térmico em \"quente\" = throttling: o aparelho se aquecendo e reduzindo desempenho.")
                    bullet("Pouca Energia ativo reduz o teto de FPS — desligue antes de jogar.")
                    bullet("Use o pico de FPS como referência antes e depois de aplicar o Turbo na aba Otimização.")
                }
            }
        }
    }

    private func systemRow(_ icon: String, _ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.16))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption.bold())
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(TBTheme.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 5)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
