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
        displayLink = link

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
        thermalObserver = nil
        powerObserver = nil
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
        memoryFootprintMB = Self.currentMemoryFootprint() / 1_048_576
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
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    fpsCard
                    memoryCard
                    thermalCard
                    tipsCard
                }
                .padding()
            }
            .navigationTitle("Desempenho")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { model.start() }
            .onDisappear { model.stop() }
        }
        .navigationViewStyle(.stack)
    }

    private var fpsCard: some View {
        VStack(spacing: 8) {
            Text("\(Int(model.fps))")
                .font(.system(size: 56, weight: .bold, design: .monospaced))
                .foregroundColor(model.fps >= 55 ? .green : (model.fps >= 45 ? .yellow : .red))
            Text("FPS atuais · quadro: \(model.frameTimeMs, specifier: "%.1f") ms")
                .font(.footnote)
                .foregroundColor(.secondary)
            Text("Máximo observado: \(Int(model.maxObservedFPS)) FPS")
                .font(.caption)
                .foregroundColor(.secondary)

            // Histórico simples em barras
            HStack(alignment: .bottom, spacing: 1) {
                ForEach(Array(model.fpsHistory.enumerated()), id: \.offset) { _, value in
                    Rectangle()
                        .fill(value >= 55 ? Color.green : (value >= 45 ? Color.yellow : Color.red))
                        .frame(height: max(2, CGFloat(value / 120) * 60))
                }
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private var memoryCard: some View {
        HStack {
            Image(systemName: "memorychip")
                .font(.title2)
            VStack(alignment: .leading) {
                Text("Memória em uso")
                    .font(.subheadline)
                Text("\(model.memoryFootprintMB, specifier: "%.1f") MB")
                    .font(.title3.monospacedDigit().bold())
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private var thermalCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "thermometer.medium")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text("Estado térmico")
                        .font(.subheadline)
                    Text(model.thermalLabel)
                        .font(.title3.bold())
                        .foregroundColor(model.thermalColor)
                }
                Spacer()
            }
            Divider()
            HStack {
                Image(systemName: model.lowPowerMode ? "battery.25" : "battery.100")
                    .font(.title2)
                    .foregroundColor(model.lowPowerMode ? .orange : .green)
                VStack(alignment: .leading) {
                    Text("Modo de Pouca Energia")
                        .font(.subheadline)
                    Text(model.lowPowerMode ? "ATIVO — limita FPS em jogos!" : "Inativo")
                        .font(.subheadline.bold())
                        .foregroundColor(model.lowPowerMode ? .orange : .green)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Como interpretar", systemImage: "lightbulb")
                .font(.headline)
            Text("• Quedas de FPS + estado térmico \"Séria/Crítica\" = throttling térmico: o aparelho está se aquecendo e reduzindo desempenho.\n• Modo de Pouca Energia ativo reduz o teto de FPS — desligue antes de jogar.\n• Se o FPS alterna entre 60 e 120, ative Limite de Quadros em Ajustes → Acessibilidade → Movimento → Limitar FPS para estabilizar em 60.\n• TouchBoost mostra o FPS máximo que SEU aparelho entrega de verdade — use como referência antes e depois de otimizações.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}
