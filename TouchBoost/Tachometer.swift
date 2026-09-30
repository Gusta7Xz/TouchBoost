import SwiftUI
import CoreHaptics

struct TouchSample: Identifiable {
    let id = UUID()
    let interval: Double // seconds between touchDown and touchUp
    let timestamp: Date
}

final class TachometerModel: ObservableObject {
    @Published var samples: [TouchSample] = []
    @Published var isMeasuring = false
    @Published var engineFailed = false

    private var engine: CHHapticEngine?
    private var downDate: Date?

    var lastInterval: Double? { samples.last?.interval }

    var stats: (min: Double, avg: Double, p95: Double, max: Double)? {
        guard samples.count >= 3 else { return nil }
        let sorted = samples.map(\.interval).sorted()
        let avg = sorted.reduce(0, +) / Double(sorted.count)
        let p95Index = min(sorted.count - 1, Int((Double(sorted.count) * 0.95).rounded(.up)) - 1)
        return (sorted.first!, avg, sorted[p95Index], sorted.last!)
    }

    func start() {
        isMeasuring = true
        prepareHaptics()
    }

    func stop() {
        isMeasuring = false
        downDate = nil
        try? engine?.stop()
    }

    func reset() {
        samples.removeAll()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesSupportsHaptics else {
            engineFailed = true
            return
        }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            engineFailed = false
        } catch {
            engineFailed = true
        }
    }

    /// Called by the view on touchDown. Returns true if this began a new measurement.
    func touchDown() -> Bool {
        guard isMeasuring else { return false }
        downDate = Date()
        playTapHaptic()
        return true
    }

    /// Called by the view on touchUp. Records the interval if a measurement was active.
    func touchUp() {
        guard isMeasuring, let start = downDate else { return }
        let interval = Date().timeIntervalSince(start)
        downDate = nil
        // Descarta toques absurdos (ex.: palma encostando na tela)
        guard interval > 0.001, interval < 1.0 else { return }
        samples.append(TouchSample(interval: interval, timestamp: Date()))
        if samples.count > 500 {
            samples.removeFirst(samples.count - 500)
        }
    }

    private func playTapHaptic() {
        guard let engine = engine, !engineFailed else { return }
        do {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
        } catch {
            // Falha silenciosa: háptico é auxiliar, não bloqueia a medição.
        }
    }
}

struct TachometerView: View {
    @StateObject private var model = TachometerModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                statsHeader
                TapPad(model: model)
                    .padding(.horizontal)
                sampleList
            }
            .navigationTitle("Taconômetro de Toque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(model.isMeasuring ? "Parar" : "Medir") {
                        model.isMeasuring ? model.stop() : model.start()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zerar") { model.reset() }
                }
            }
            .onDisappear { model.stop() }
        }
        .navigationViewStyle(.stack)
    }

    private var statsHeader: some View {
        Group {
            if let s = model.stats {
                HStack(spacing: 12) {
                    statCard("Mín", s.min, color: .green)
                    statCard("Médio", s.avg, color: .yellow)
                    statCard("P95", s.p95, color: .orange)
                    statCard("Máx", s.max, color: .red)
                }
            } else {
                Text("Toque repetidamente na área abaixo para medir a latência de toque (intervalo entre press e release).\n\nAtive \"Medir\" para começar e receber vibração a cada toque.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }

    private func statCard(_ label: String, _ value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(String(format: "%.0f", value * 1000))
                .font(.title3.monospacedDigit().bold())
                .foregroundColor(color)
            Text("ms")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }

    private var sampleList: some View {
        Group {
            if !model.samples.isEmpty {
                List(model.samples.suffix(50).reversed()) { sample in
                    HStack {
                        Text(sample.timestamp, style: .time)
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.1f ms", sample.interval * 1000))
                            .font(.body.monospacedDigit())
                            .foregroundColor(sample.interval < 0.08 ? .green : (sample.interval < 0.12 ? .yellow : .red))
                    }
                    .listRowBackground(Color(.secondarySystemBackground))
                }
                .listStyle(.plain)
            } else {
                Spacer()
            }
        }
    }
}

/// Área de toque: relata touchDown/touchUp com o menor atraso possível.
struct TapPad: UIViewRepresentable {
    let model: TachometerModel

    func makeUIView(context: Context) -> PadView {
        let v = PadView()
        v.model = model
        v.backgroundColor = UIColor.secondarySystemBackground
        v.layer.cornerRadius = 16
        v.isMultipleTouchEnabled = true
        return v
    }

    func updateUIView(_ uiView: PadView, context: Context) {}

    final class PadView: UIView {
        weak var model: TachometerModel?
        private var trackedTouches: [UITouch: Date] = [:]

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesBegan(touches, with: event)
            for t in touches {
                trackedTouches[t] = Date()
                _ = model?.touchDown()
            }
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.25)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesEnded(touches, with: event)
            for t in touches {
                if let start = trackedTouches[t] {
                    let interval = Date().timeIntervalSince(start)
                    trackedTouches.removeValue(forKey: t)
                    if model?.isMeasuring == true, interval > 0.001, interval < 1.0 {
                        model?.samples.append(TouchSample(interval: interval, timestamp: Date()))
                    }
                }
            }
            if trackedTouches.isEmpty {
                backgroundColor = UIColor.secondarySystemBackground
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            for t in touches { trackedTouches.removeValue(forKey: t) }
            if trackedTouches.isEmpty {
                backgroundColor = UIColor.secondarySystemBackground
            }
        }
    }
}
