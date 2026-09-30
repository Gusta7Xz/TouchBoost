import SwiftUI
import UIKit

// MARK: - Aba 🚀 Otimização

final class TemperatureGuardModel: ObservableObject {
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var coolingActive = false

    init() {
        thermalState = ProcessInfo.processInfo.thermalState
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.update()
        }
    }

    func update() {
        thermalState = ProcessInfo.processInfo.thermalState
        // Com o controle ativo, reduz o teto de quadros automaticamente quando esquenta.
        if coolingActive && thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
            TurboPerf.disableHighThroughputMode()
        } else if coolingActive {
            TurboPerf.enableHighThroughputMode()
        }
    }

    var label: String {
        switch thermalState {
        case .nominal: return "Temperatura normal"
        case .fair: return "Morna"
        case .serious: return "Quente — reduzindo"
        case .critical: return "Muito quente — protegendo"
        @unknown default: return "—"
        }
    }

    var color: Color {
        switch thermalState {
        case .nominal: return TBTheme.accent
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    var gauge: Double {
        switch thermalState {
        case .nominal: return 0.2
        case .fair: return 0.45
        case .serious: return 0.72
        case .critical: return 1.0
        @unknown default: return 0.2
        }
    }
}

struct OptimizationTabView: View {
    // Ajustes de Otimização
    @AppStorage("opt.sensBoost") private var sensBoost: Double = 70
    @AppStorage("opt.delayCut") private var delayCut: Double = 90
    @AppStorage("opt.perfBoost") private var perfBoost: Double = 60

    // Recursos Extra
    @AppStorage("opt.gameTurbo") private var gameTurbo = false
    @AppStorage("opt.tempControl") private var tempControl = false
    @AppStorage("opt.touchProtection") private var touchProtection = false

    // Desempenho
    @AppStorage("opt.antiDelay") private var antiDelay = true
    @AppStorage("opt.gpuPriority") private var gpuPriority = true
    @AppStorage("opt.processBoost") private var processBoost = true

    @StateObject private var temp = TemperatureGuardModel()
    @StateObject private var maintenance = MaintenanceModel()
    @StateObject private var session = TurboSessionModel()

    @State private var applyStatus = ""

    var body: some View {
        TBScreen {
            TBHero(
                title: "TOUCHBOOST PRO",
                subtitle: "Otimização completa do sistema",
                systemImage: "bolt.fill",
                stat1: ("+\(Int(sensBoost))%", "Sensibilidade"),
                stat2: ("-\(Int(delayCut))%", "Delay"),
                stat3: ("+\(Int(perfBoost))%", "Desempenho")
            )

            TBSectionHeader(title: "Ajustes de Otimização")

            TBSliderRow(
                title: "Sensibilidade da tela",
                detail: "Amplifica a resposta do toque",
                icon: "hand.tap.fill", iconColor: .green,
                value: $sensBoost, range: 0...100, suffix: "%"
            )
            TBSliderRow(
                title: "Redução de delay do toque",
                detail: "Corta a latência entre toque e resposta",
                icon: "timer", iconColor: .orange,
                value: $delayCut, range: 0...90, suffix: "%"
            )
            TBSliderRow(
                title: "Desempenho em jogos",
                detail: "Turbo extra de processamento",
                icon: "gamecontroller.fill", iconColor: .blue,
                value: $perfBoost, range: 0...60, suffix: "%"
            )

            TBSectionHeader(title: "Recursos Extra")

            TBToggleRow(
                title: "Game Turbo",
                detail: "Ativa todos os boosts para jogar",
                icon: "bolt.circle.fill", iconColor: .yellow,
                isOn: $gameTurbo
            )
            .onChange(of: gameTurbo) { on in
                if on {
                    sensBoost = 70
                    delayCut = 90
                    perfBoost = 60
                    antiDelay = true
                    gpuPriority = true
                    processBoost = true
                    applyAll()
                    maintenance.warmUp()
                }
            }

            TBToggleRow(
                title: "Controle de Temperatura",
                detail: temp.label,
                icon: "thermometer.medium", iconColor: temp.color,
                isOn: $tempControl
            )
            .onChange(of: tempControl) { on in
                temp.coolingActive = on
                temp.update()
            }

            temperatureCard

            TBToggleRow(
                title: "Proteção de Toque",
                detail: "Filtra toques acidentais da palma",
                icon: "hand.raised.fill", iconColor: .purple,
                isOn: $touchProtection
            )

            TBSectionHeader(title: "Desempenho")

            TBToggleRow(
                title: "Anti-delay",
                detail: "Tela sempre acesa, sem pausas",
                icon: "timer", iconColor: .orange,
                isOn: $antiDelay
            )
            TBToggleRow(
                title: "Prioridade de GPU (120 Hz)",
                detail: "Taxa máxima de quadros",
                icon: "gauge.high", iconColor: .blue,
                isOn: $gpuPriority
            )
            TBToggleRow(
                title: "Boost de processos",
                detail: "Prioridade máxima de execução",
                icon: "cpu.fill", iconColor: .red,
                isOn: $processBoost
            )

            TBSectionHeader(title: "Manutenção")

            maintenanceCard

            TBSectionHeader(title: "Sessão de Jogo")

            sessionCard

            TBPrimaryButton(title: "APLICAR OTIMIZAÇÕES", systemImage: "bolt.fill") {
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
        .onAppear { maintenance.refresh() }
    }

    // MARK: Cartão de temperatura

    private var temperatureCard: some View {
        TBCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "thermometer.medium")
                        .foregroundColor(temp.color)
                    Text("Temperatura do aparelho")
                        .font(.subheadline.bold())
                    Spacer()
                    Text(temp.label)
                        .font(.caption.bold())
                        .foregroundColor(temp.color)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * 0.25)
                            .opacity(0.25)
                        Capsule()
                            .fill(temp.color)
                            .frame(width: max(24, geo.size.width * temp.gauge))
                    }
                }
                .frame(height: 10)
            }
        }
    }

    // MARK: Cartão de manutenção

    private var maintenanceCard: some View {
        TBCard {
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "memorychip").foregroundColor(.blue)
                        Text("Memória").font(.caption)
                        Text(String(format: "%.0f MB", maintenance.memMB))
                            .font(.caption.monospacedDigit().bold())
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "externaldrive").foregroundColor(.orange)
                        Text("Cache").font(.caption)
                        Text(String(format: "%.1f MB", maintenance.cacheMB))
                            .font(.caption.monospacedDigit().bold())
                    }
                }

                HStack(spacing: 10) {
                    smallButton("Liberar RAM", "wind") { maintenance.purgeMemory() }
                    smallButton("Limpar Cache", "trash") { maintenance.clearCache() }
                    smallButton("Aquecer CPU", "flame") { maintenance.warmUp() }
                }

                if !maintenance.resultText.isEmpty {
                    Text(maintenance.resultText)
                        .font(.caption.monospacedDigit())
                        .foregroundColor(TBTheme.accent)
                }
            }
        }
    }

    private func smallButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Cartão de sessão

    private var sessionCard: some View {
        TBCard {
            if session.isRunning {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int(session.fps))")
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundColor(TBTheme.accent)
                            Text("FPS")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(String(format: "%02d:%02d", session.seconds / 60, session.seconds % 60))
                                .font(.system(.title2, design: .rounded).bold())
                            Text("tempo de sessão")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Button {
                        session.stop()
                    } label: {
                        Label("Encerrar sessão", systemImage: "stop.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    session.start()
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Iniciar Sessão de Jogo")
                                .font(.subheadline.bold())
                            Text("Ativa todos os boosts e monitora o FPS")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Ação principal

    private func applyAll() {
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

        TurboPerf.setZeroAnimations(delayCut >= 70)

        applyStatus = "Aplicado: sensibilidade +\(Int(sensBoost))% · delay -\(Int(delayCut))% · desempenho +\(Int(perfBoost))%\(gameTurbo ? " · Game Turbo ON" : "")\(tempControl ? " · controle térmico ON" : "")\(touchProtection ? " · proteção de toque ON" : "")"
    }
}
