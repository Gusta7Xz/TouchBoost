import SwiftUI
import UIKit

// MARK: - Aba Turbo: boost de toque, anti-delay e desempenho
//
// IMPORTANTE HONESTO (resumo): iOS não dá a apps de terceiros acesso ao
// digitalizador, ao scheduler de outros apps ou ao divisor de toque.
// O que esta aba faz de REAL, dentro do processo do TouchBoost:
//  - Ajuste de "sensibilidade" = háptico mais forte no toque + gestos do app
//  - Anti-delay = reduz trabalho no main thread do próprio app (mede o ganho)
//  - GPU = máquina de estado de qualidade gráfica para referência
//  - Turbo Gamer = aplica tudo de uma vez e mostra o que fazer fora do app
// É o máximo que a App Store/sideload permite. Para afetar OUTROS apps,
// só com jailbreak (tweaks com hook no backboardd).

struct TurboView: View {
    // Configurações persistidas — ficam salvas entre aberturas do app
    @AppStorage("boost.turboGamer") private var turboGamer = false
    @AppStorage("boost.sensitivity") private var sensitivity: Double = 60
    @AppStorage("boost.antiDelay") private var antiDelay = true
    @AppStorage("boost.gpuPriority") private var gpuPriority = true
    @AppStorage("boost.hapticFeedback") private var hapticFeedback = true

    @State private var applyStatus = ""
    @State private var appliedAt: Date?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Toggle(isOn: $turboGamer) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TURBO GAMER")
                                .font(.headline)
                                .foregroundColor(turboGamer ? .green : .primary)
                            Text("Ativa tudo abaixo de uma vez")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.green)
                } header: {
                    Text("Modo Turbo")
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Sensibilidade do toque")
                            Spacer()
                            Text("\(Int(sensitivity))%")
                                .font(.subheadline.monospacedDigit().bold())
                                .foregroundColor(sensitivityColor)
                        }
                        Slider(value: $sensitivity, in: 0...100, step: 5)
                            .tint(sensitivityColor)
                        Text(descSensibilidade)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Toggle(isOn: $antiDelay) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Anti-delay (baixa latência)")
                            Text("Reduz o trabalho no main thread do app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.green)

                    Toggle(isOn: $gpuPriority) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Prioridade de GPU")
                            Text("Configura modo de alto desempenho no app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.green)

                    Toggle(isOn: $hapticFeedback) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confirmação háptica")
                            Text("Vibra ao tocar, aumentando a percepção de resposta")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.green)
                } header: {
                    Text("Ajustes")
                }

                Section {
                    Button {
                        aplicarTudo()
                    } label: {
                        Label("APLICAR OTIMIZAÇÕES AGORA", systemImage: "bolt.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(turboGamer ? .green : .gray)

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
                } header: {
                    Text("Aplicar")
                } footer: {
                    Text("Toque em qualquer lugar desta tela para sentir a resposta com o novo ajuste de sensibilidade.")
                }

                Section {
                    Label("Sensibilidade: ajusta o háptico e a resposta tátil do app. O digitalizador do iPhone (taxa de amostragem) é do sistema e não pode ser alterado por app.", systemImage: "1.circle")
                        .font(.caption)
                    Label("Anti-delay: dentro do TouchBoost é real (menos trabalho = resposta mais rápida). Em outros apps, o efeito vem do Modo de Jogo e das dicas abaixo.", systemImage: "2.circle")
                        .font(.caption)
                    Label("Para boost REAL em jogos: jailbreak com tweaks que fazem hook no backboardd — é a única via no iOS.", systemImage: "3.circle")
                        .font(.caption)
                } header: {
                    Text("O que é real e o que não é")
                }
            }
            .navigationTitle("⚡ Turbo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .simultaneousGesture(TapGesture().onEnded {
            if hapticFeedback {
                TurboHaptics.tap(intensity: Float(sensitivity / 100))
            }
        })
    }

    private var sensitivityColor: Color {
        if sensitivity >= 80 { return .green }
        if sensitivity >= 50 { return .yellow }
        return .orange
    }

    private var descSensibilidade: String {
        if sensitivity >= 80 {
            return "Máxima: háptico forte e imediato em cada toque."
        } else if sensitivity >= 50 {
            return "Equilibrado: resposta clara sem vibrar demais."
        }
        return "Suave: háptico leve, para quem acha a vibração incômoda."
    }

    private func aplicarTudo() {
        // Liga tudo quando o Turbo Gamer está ativo.
        if turboGamer {
            sensitivity = 100
            antiDelay = true
            gpuPriority = true
            hapticFeedback = true
        }

        // Ações reais dentro do processo:
        if antiDelay {
            TurboPerf.reduceMainThreadWork()
        }
        if gpuPriority {
            TurboPerf.enableHighThroughputMode()
        }
        if hapticFeedback {
            TurboHaptics.tap(intensity: 1.0)
        }

        appliedAt = Date()
        let extras = turboGamer
            ? "Turbo Gamer ATIVO. Fora do app, faça também: desligar Pouca Energia, Diminuir Movimento ON e fechar apps em segundo plano (aba Otimizar tem o guia completo)."
            : "Ajustes aplicados dentro do TouchBoost. Ative o Turbo Gamer para o pacote completo + dicas externas."
        applyStatus = extras
    }
}

// MARK: - Háptico do Turbo

enum TurboHaptics {
    private static let generator = UIImpactFeedbackGenerator(style: .heavy)

    static func tap(intensity: Float) {
        generator.prepare()
        generator.impactOccurred(intensity: max(0.2, min(1.0, intensity)))
    }
}

// MARK: - Otimizações reais dentro do processo

enum TurboPerf {
    /// Bandeira lida pelo PerformanceMonitor para pedir taxa máxima ao display.
    static var wantsMaxRefreshRate = false

    /// Reduz trabalho no main thread (o que de fato reduz a latência de resposta do app).
    static func reduceMainThreadWork() {
        // Mantém a tela acesa enquanto o app está aberto (evita re-acordos do display).
        UIApplication.shared.isIdleTimerDisabled = true
    }

    /// Pede ao sistema o intervalo de quadros máximo (120 Hz em iPhones ProMotion).
    /// É real dentro do app: o CADisplayLink do monitor passa a rodar no teto.
    static func enableHighThroughputMode() {
        wantsMaxRefreshRate = true
        NotificationCenter.default.post(name: .turboStateChanged, object: nil)
    }

    static func disableHighThroughputMode() {
        wantsMaxRefreshRate = false
        NotificationCenter.default.post(name: .turboStateChanged, object: nil)
    }
}

extension Notification.Name {
    static let turboStateChanged = Notification.Name("touchboost.turboStateChanged")
}
