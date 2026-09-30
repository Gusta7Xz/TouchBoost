import SwiftUI
import UIKit

// MARK: - Aba 🚀 Otimização: exclusivamente funções de desempenho e sistema

struct OptimizationTabView: View {
    @AppStorage("opt.turbo") private var optTurbo = false
    @AppStorage("opt.preset") private var preset = 2
    @AppStorage("opt.antiDelay") private var antiDelay = true
    @AppStorage("opt.gpuPriority") private var gpuPriority = true
    @AppStorage("opt.processBoost") private var processBoost = true

    @StateObject private var maintenance = MaintenanceModel()
    @StateObject private var session = TurboSessionModel()

    @State private var applyStatus = ""

    var body: some View {
        NavigationView {
            Form {
                masterSection
                togglesSection
                MaintenanceSection(model: maintenance)
                SessionSectionView(session: session)
                applySection
            }
            .navigationTitle("🚀 Otimização")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { maintenance.refresh() }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: Seções

    private var masterSection: some View {
        Section {
            Toggle(isOn: $optTurbo) {
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title)
                        .foregroundColor(optTurbo ? .green : .gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TURBO DE OTIMIZAÇÃO")
                            .font(.headline)
                            .foregroundColor(optTurbo ? .green : .primary)
                        Text("Desempenho máximo com um toque")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.green)
            .onChange(of: optTurbo) { on in
                if on {
                    preset = 2
                    applyPreset()
                    applyAll()
                    maintenance.warmUp()
                }
            }

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

    private var togglesSection: some View {
        Section("Desempenho") {
            Toggle(isOn: $antiDelay) {
                Label("Anti-delay (tela sempre acesa)", systemImage: "timer")
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
        }
    }

    private var applySection: some View {
        Section {
            Button {
                applyAll()
            } label: {
                Label("APLICAR OTIMIZAÇÕES", systemImage: "bolt.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(optTurbo ? .green : .blue)

            if !applyStatus.isEmpty {
                Text(applyStatus)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Ações

    private func applyPreset() {
        switch preset {
        case 0:
            antiDelay = false
            gpuPriority = false
            processBoost = false
        case 1:
            antiDelay = true
            gpuPriority = false
            processBoost = true
        default:
            antiDelay = true
            gpuPriority = true
            processBoost = true
        }
    }

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

        applyStatus = "Otimizações aplicadas: anti-delay \(antiDelay ? "ON" : "OFF"), GPU \(gpuPriority ? "120 Hz" : "padrão"), processos \(processBoost ? "prioritários" : "normais")."
    }
}

// MARK: - Seção de manutenção (memória, cache, CPU)

struct MaintenanceSection: View {
    @ObservedObject var model: MaintenanceModel

    var body: some View {
        Section("Manutenção") {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.blue)
                Text("Memória em uso")
                Spacer()
                Text(String(format: "%.0f MB", model.memMB))
                    .font(.subheadline.monospacedDigit().bold())
            }

            Button {
                model.purgeMemory()
            } label: {
                Label("Liberar memória agora", systemImage: "wind")
            }

            HStack {
                Image(systemName: "externaldrive")
                    .foregroundColor(.orange)
                Text("Cache do app")
                Spacer()
                Text(String(format: "%.1f MB", model.cacheMB))
                    .font(.subheadline.monospacedDigit().bold())
            }

            Button {
                model.clearCache()
            } label: {
                Label("Limpar cache do app", systemImage: "trash")
            }

            Button {
                model.warmUp()
            } label: {
                Label("Aquecer CPU (2s)", systemImage: "flame")
            }

            if !model.resultText.isEmpty {
                Text(model.resultText)
                    .font(.footnote.monospacedDigit())
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Seção de sessão de jogo

struct SessionSectionView: View {
    @ObservedObject var session: TurboSessionModel

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
