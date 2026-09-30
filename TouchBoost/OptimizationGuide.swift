import SwiftUI

// MARK: - Aba 💡 Dicas: guia de ajustes do sistema

struct OptimizationGuideView: View {
    var body: some View {
        TBScreen {
            TBHero(
                title: "DICAS DE OTIMIZAÇÃO",
                subtitle: "Ajustes do iOS que aceleram o aparelho",
                systemImage: "lightbulb.fill",
                stat1: ("15", "Dicas"),
                stat2: ("4", "Categorias"),
                stat3: ("5 min", "Leitura")
            )

            tipSection("🔥 Maior Impacto", [
                Tip("Desligue o Modo de Pouca Energia", "Ajustes → Bateria. Ele reduz o teto de FPS do aparelho inteiro e adiciona input lag. É o ajuste nº 1 para jogos.", "battery.25", .orange),
                Tip("Diminuir Movimento: LIGADO", "Ajustes → Acessibilidade → Movimento → Diminuir Movimento: ON. Corta animações do sistema e o conteúdo chega mais rápido.", "arrow.left.arrow.right.circle", .blue),
                Tip("Ative o modo 120 Hz (ProMotion)", "Só iPhone Pro. Ajustes → Acessibilidade → Movimento → Limite de Quadros: Desativado. Se o jogo não é fluido em 120, limite para 60 — estabilidade vale mais.", "display", .purple),
                Tip("Feche todos os apps em segundo plano", "Troque de app e feche tudo antes de jogar. RAM livre evita o sistema recarregar o jogo do zero quando ele é suspenso.", "xmark.app", .red)
            ])

            tipSection("🎮 Jogos — Input Lag", [
                Tip("Gráficos baixos e FPS alto nas configs do jogo", "Dentro do jogo: FoV alto e gráficos baixos → mais FPS → menos delay por quadro. 120 FPS = input lido a cada 8 ms; 30 FPS = a cada 33 ms.", "gamecontroller", .green),
                Tip("Procure o Modo de Jogo do iOS", "Em versões recentes do iOS, o Modo de Jogo reduz atividade em segundo plano e prioriza toque/Bluetooth automaticamente.", "trophy", .yellow),
                Tip("Bluetooth: desligue o que não usa", "Cada dispositivo Bluetooth adiciona 20–100 ms de latência em áudio/entrada. Se joga com som, prefira fone com fio.", "antenna.radiowaves.left.and.right.slash", .blue)
            ])

            tipSection("🌐 Rede — Ping", [
                Tip("Wi-Fi 5 GHz em vez de 2,4 GHz", "5 GHz tem menos interferência e latência estável (1–5 ms até o roteador). 2,4 GHz sofre com micro-ondas e vizinhos. Compare com a aba Rede.", "wifi", .green),
                Tip("Fique perto do roteador", "Cada parede multiplica retransmissões. Meça o ping até o IP do roteador na aba Rede — se for alto, o problema é o sinal.", "dot.radiowaves.left.and.right", .blue),
                Tip("Pare downloads antes de jogar", "Downloads em segundo plano causam picos de ping (100+ ms). Pause em Ajustes → Geral → Atualização em Segundo Plano.", "arrow.down.circle", .orange)
            ])

            tipSection("🔋 Sustentação — Sem Throttling", [
                Tip("Tire a capinha antes de jogar", "O calor fica retido e dispara o throttling térmico (acompanhe na aba Desempenho). Sem capinha = FPS estável por mais tempo.", "thermometer.sun", .red),
                Tip("Cuidado ao carregar jogando", "Carregar enquanto joga aquece o dobro. Se precisar, use carregador de potência alta e sem capinha.", "bolt.badge.clock", .yellow),
                Tip("Brilho entre 50–70%", "Brilho máximo em OLED aquece o aparelho e acelera throttling. 50% é o ponto ideal entre visibilidade e temperatura.", "sun.min", .orange),
                Tip("Reinicie o iPhone antes de sessões longas", "Semana sem reiniciar = processos acumulando RAM. Reiniciar dá o melhor estado possível para o jogo.", "arrow.clockwise.circle", .blue)
            ])
        }
    }

    private func tipSection(_ title: String, _ tips: [Tip]) -> some View {
        VStack(spacing: 10) {
            TBSectionHeader(title: title)
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                TipCard(tip: tip)
            }
        }
    }
}

struct Tip {
    let title: String
    let detail: String
    let icon: String
    let color: Color
}

struct TipCard: View {
    let tip: Tip

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tip.color.opacity(0.16))
                    .frame(width: 38, height: 38)
                Image(systemName: tip.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tip.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(tip.detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TBTheme.cardGradient)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
}
