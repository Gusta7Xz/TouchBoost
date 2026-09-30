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
        TBScreen {
            TBHero(
                title: "TOQUE TURBO",
                subtitle: "Sensibilidade e resposta tátil",
                systemImage: "hand.tap.fill",
                stat1: ("\(Int(sensitivity))%", "Força"),
                stat2: ("\(Int(sharpness))%", "Textura"),
                stat3: (hapticFeedback ? "ON" : "OFF", "Háptico")
            )

            TBSectionHeader(title: "Sensibilidade do Toque")

            TBSliderRow(
                title: "Força do toque",
                detail: "Intensidade da resposta a cada toque",
                icon: "hand.tap.fill", iconColor: .green,
                value: $sensitivity, range: 0...100, suffix: "%"
            )
            TBSliderRow(
                title: "Textura do toque",
                detail: "Nitidez da vibração (seca a cristalina)",
                icon: "waveform.path", iconColor: .blue,
                value: $sharpness, range: 0...100, suffix: "%"
            )

            TBCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PRESETS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 10) {
                        presetCard("Suave", 55, 25, "cloud.fill")
                        presetCard("Precisão", 75, 85, "scope")
                        presetCard("FPS Rápido", 100, 60, "bolt.fill")
                    }
                }
            }

            TBSectionHeader(title: "Feedback e Resposta")

            TBToggleRow(
                title: "Confirmação háptica",
                detail: "Vibra em cada toque na força escolhida",
                icon: "iphone.radiowaves.left.and.right", iconColor: .green,
                isOn: $hapticFeedback
            )
            TBToggleRow(
                title: "Resposta instantânea",
                detail: "Zero animações entre toque e ação",
                icon: "minus.circle", iconColor: .orange,
                isOn: $instantResponse
            )
            TBToggleRow(
                title: "Tela imersiva",
                detail: "Remove a barra de status",
                icon: "arrow.up.backward.and.arrow.down.forward", iconColor: .purple,
                isOn: $immersiveScreen
            )

            TBPrimaryButton(title: "APLICAR TOQUE", systemImage: "hand.tap.fill") {
                applyAll()
            }

            if !applyStatus.isEmpty {
                Text(applyStatus)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            if hapticFeedback {
                TurboHapticsEngine.shared.tap(intensity: Float(sensitivity / 100), sharpness: Float(sharpness / 100))
            }
        })
    }

    private func presetCard(_ title: String, _ s: Double, _ sh: Double, _ icon: String) -> some View {
        let selected = sensitivity == s && sharpness == sh
        return Button {
            sensitivity = s
            sharpness = sh
            if hapticFeedback {
                TurboHapticsEngine.shared.tap(intensity: Float(s / 100), sharpness: Float(sh / 100))
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(selected ? TBTheme.accent : .secondary)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(selected ? TBTheme.accent : .primary)
                Text("\(Int(s))/\(Int(sh))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? TBTheme.accent.opacity(0.14) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(selected ? TBTheme.accent.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func applyAll() {
        TurboPerf.setZeroAnimations(instantResponse)
        if hapticFeedback {
            TurboHapticsEngine.shared.tap(intensity: Float(sensitivity / 100), sharpness: Float(sharpness / 100))
        }
        applyStatus = "Toque aplicado: força \(Int(sensitivity))% · textura \(Int(sharpness))% · háptico \(hapticFeedback ? "ON" : "OFF") · resposta \(instantResponse ? "instantânea" : "padrão")"
    }
}
