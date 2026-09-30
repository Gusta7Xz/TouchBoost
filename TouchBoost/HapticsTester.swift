import SwiftUI
import CoreHaptics

final class HapticsTesterModel: ObservableObject {
    @Published var statusText = "Pronto"
    @Published var engineAvailable = true

    private var engine: CHHapticEngine?

    init() {
        prepareEngine()
    }

    private func prepareEngine() {
        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            engineAvailable = false
            statusText = "Falha ao iniciar háptico: \(error.localizedDescription)"
        }
    }

    func playTransient(intensity: Float, sharpness: Float) {
        guard let engine = engine else { return }
        do {
            let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [i, s], relativeTime: 0)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
            statusText = String(format: "Transient — intensidade %.2f, nitidez %.2f", intensity, sharpness)
        } catch {
            statusText = "Erro: \(error.localizedDescription)"
        }
    }

    func playContinuous(intensity: Float, sharpness: Float, duration: Double) {
        guard let engine = engine else { return }
        do {
            let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [i, s], relativeTime: 0, duration: duration)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: 0)
            statusText = String(format: "Contínuo %.2fs — intensidade %.2f", duration, intensity)
        } catch {
            statusText = "Erro: \(error.localizedDescription)"
        }
    }

    func playPresetClick() {
        // Feedback rápido estilo "clique" — bom para testar resposta de disparo em jogos.
        playTransient(intensity: 1.0, sharpness: 0.9)
    }

    func fallbackImpact() {
        // Reserva para dispositivos sem CoreHaptics (ex.: iPhone SE 1ª ger.)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        statusText = "UIImpactFeedbackGenerator (fallback)"
    }
}

struct HapticsTesterView: View {
    @StateObject private var model = HapticsTesterModel()
    @State private var intensity: Float = 0.8
    @State private var sharpness: Float = 0.7
    @State private var continuousDuration: Double = 0.3

    var body: some View {
        NavigationView {
            Form {
                Section {
                    if !model.engineAvailable {
                        Label("CoreHaptics indisponível neste dispositivo — usando UIImpactFeedbackGenerator como reserva.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                    Toggle("Motor háptico disponível", isOn: .constant(model.engineAvailable))
                        .disabled(true)
                } header: {
                    Text("Status")
                }

                Section {
                    VStack(alignment: .leading) {
                        Text("Intensidade: \(intensity, specifier: "%.2f")")
                        Slider(value: $intensity, in: 0.1...1.0)
                    }
                    VStack(alignment: .leading) {
                        Text("Nitidez: \(sharpness, specifier: "%.2f")")
                        Slider(value: $sharpness, in: 0.1...1.0)
                    }
                    Button {
                        if model.engineAvailable {
                            model.playTransient(intensity: intensity, sharpness: sharpness)
                        } else {
                            model.fallbackImpact()
                        }
                    } label: {
                        Label("Disparar toque único (transient)", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } header: {
                    Text("Evento único")
                } footer: {
                    Text("Transient é o evento mais curto possível: útil para sentir o \"clique\" mínimo do háptico.")
                }

                Section {
                    VStack(alignment: .leading) {
                        Text("Duração: \(continuousDuration, specifier: "%.2f") s")
                        Slider(value: $continuousDuration, in: 0.05...2.0)
                    }
                    Button {
                        if model.engineAvailable {
                            model.playContinuous(intensity: intensity, sharpness: sharpness, duration: continuousDuration)
                        } else {
                            model.fallbackImpact()
                        }
                    } label: {
                        Label("Disparar vibração contínua", systemImage: "waveform")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } header: {
                    Text("Evento contínuo")
                }

                Section {
                    Button("Preset: clique de disparo (FPS)") {
                        if model.engineAvailable {
                            model.playPresetClick()
                        } else {
                            model.fallbackImpact()
                        }
                    }
                    Button("Preset: recuo suave (recarga)") {
                        if model.engineAvailable {
                            model.playContinuous(intensity: 0.5, sharpness: 0.3, duration: 0.15)
                        } else {
                            model.fallbackImpact()
                        }
                    }
                } header: {
                    Text("Presets de jogo")
                }

                Section {
                    Text(model.statusText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Teste Háptico")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}
