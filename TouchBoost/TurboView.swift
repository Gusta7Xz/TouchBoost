import SwiftUI
import UIKit

// MARK: - Aba ⚡ Toque: exclusivamente funções de toque e resposta tátil

struct TouchTabView: View {
    @AppStorage("touch.turbo") private var touchTurbo = false
    @AppStorage("touch.sensitivity") private var sensitivity: Double = 80
    @AppStorage("touch.sharpness") private var sharpness: Double = 70
    @AppStorage("touch.hapticFeedback") private var hapticFeedback = true
    @AppStorage("touch.instantResponse") private var instantResponse = false
    @AppStorage("touch.immersiveScreen") private var immersiveScreen = false

    @State private var applyStatus = ""

    var body: some View {
        NavigationView {
            Form {
                masterSection
                sensitivitySection
                feedbackSection
                responseSection
                applySection
            }
            .navigationTitle("⚡ Toque")
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
            Toggle(isOn: $touchTurbo) {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .font(.title)
                        .foregroundColor(touchTurbo ? .green : .gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TURBO DE TOQUE")
                            .font(.headline)
                            .foregroundColor(touchTurbo ? .green : .primary)
                        Text("Sensibilidade máxima com um toque")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            .onChange(of: touchTurbo) { on in
                if on {
                    sensitivity = 100
                    sharpness = 80
                    hapticFeedback = true
                    instantResponse = true
                    immersiveScreen = true
                    applyAll()
                }
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
            if hapticFeedback {
                TurboHapticsEngine.shared.tap(intensity: Float(s / 100), sharpness: Float(sh / 100))
            }
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

    private var feedbackSection: some View {
        Section("Feedback tátil") {
            Toggle(isOn: $hapticFeedback) {
                Label("Confirmação háptica", systemImage: "iphone.radiowaves.left.and.right")
            }
            .tint(.green)
        }
    }

    private var responseSection: some View {
        Section("Resposta da tela") {
            Toggle(isOn: $instantResponse) {
                Label("Resposta instantânea (zero animações)", systemImage: "minus.circle")
            }
            .tint(.green)

            Toggle(isOn: $immersiveScreen) {
                Label("Tela imersiva (sem barra de status)", systemImage: "arrow.up.backward.and.arrow.down.forward")
            }
            .tint(.green)
        }
    }

    private var applySection: some View {
        Section {
            Button {
                applyAll()
            } label: {
                Label("APLICAR TOQUE", systemImage: "hand.tap.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(touchTurbo ? .green : .blue)

            if !applyStatus.isEmpty {
                Text(applyStatus)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Ações

    private func applyAll() {
        TurboPerf.setZeroAnimations(instantResponse)
        if hapticFeedback {
            TurboHapticsEngine.shared.tap(intensity: Float(sensitivity / 100), sharpness: Float(sharpness / 100))
        }
        applyStatus = "Toque aplicado: força \(Int(sensitivity))%, textura \(Int(sharpness))%, háptico \(hapticFeedback ? "ON" : "OFF"), resposta \(instantResponse ? "instantânea" : "padrão")."
    }
}
