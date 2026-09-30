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
        // CHHapticEngine() lança erro em dispositivos sem Taptic Engine compatível.
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
        TBScreen {
            TBHero(
                title: "TACONÔMETRO",
                subtitle: model.isMeasuring ? "Medindo… toque na área abaixo" : "Latência real entre press e release",
                systemImage: "speedometer",
                stat1: model.stats.map { String(format: "%.0f", $0.min * 1000) } ?? "—",
                stat2: model.stats.map { String(format: "%.0f", $0.avg * 1000) } ?? "—",
                stat3: model.stats.map { String(format: "%.0f", $0.p95 * 1000) } ?? "—"
            )

            TBSectionHeader(title: "Área de Medição")

            TapPad(model: model)
                .frame(height: 170)

            HStack(spacing: 10) {
                Button {
                    if model.isMeasuring { model.stop() } else { model.start() }
                } label: {
                    Label(model.isMeasuring ? "Parar" : "Medir", systemImage: model.isMeasuring ? "stop.fill" : "play.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(model.isMeasuring ? .red : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(model.isMeasuring ? Color.red.opacity(0.14) : TBTheme.accent))
                }
                .buttonStyle(.plain)

                Button {
                    model.reset()
                } label: {
                    Label("Zerar", systemImage: "arrow.counterclockwise")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }

            if let s = model.stats {
                TBSectionHeader(title: "Estatísticas")
                TBCard {
                    HStack(spacing: 10) {
                        tapStat("Mín", s.min * 1000, .green)
                        tapStat("Médio", s.avg * 1000, .yellow)
                        tapStat("P95", s.p95 * 1000, .orange)
                        tapStat("Máx", s.max * 1000, .red)
                    }
                }
            }

            if !model.samples.isEmpty {
                TBSectionHeader(title: "Últimos Toques")
                TBCard {
                    VStack(spacing: 8) {
                        ForEach(Array(model.samples.suffix(6).enumerated().reversed()), id: \.element.id) { _, sample in
                            HStack {
                                Text(sample.timestamp, style: .time)
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.1f ms", sample.interval * 1000))
                                    .font(.subheadline.monospacedDigit().bold())
                                    .foregroundColor(sample.interval < 0.08 ? TBTheme.accent : (sample.interval < 0.12 ? .yellow : .red))
                            }
                        }
                    }
                }
            }
        }
        .onDisappear { model.stop() }
    }

    private func tapStat(_ label: String, _ ms: Double, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(String(format: "%.0f", ms))
                .font(.system(.headline, design: .rounded).bold())
                .foregroundColor(color)
            Text(label + " (ms)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
    }
}

/// Área de toque: relata touchDown/touchUp com o menor atraso possível.
struct TapPad: UIViewRepresentable {
    let model: TachometerModel

    func makeUIView(context: Context) -> PadView {
        let v = PadView()
        v.model = model
        v.backgroundColor = UIColor(red: 0.07, green: 0.11, blue: 0.14, alpha: 1)
        v.layer.cornerRadius = 18
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
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
                backgroundColor = UIColor(red: 0.07, green: 0.11, blue: 0.14, alpha: 1)
            }
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            super.touchesCancelled(touches, with: event)
            for t in touches { trackedTouches.removeValue(forKey: t) }
            if trackedTouches.isEmpty {
                backgroundColor = UIColor(red: 0.07, green: 0.11, blue: 0.14, alpha: 1)
            }
        }
    }
}
