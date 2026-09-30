import SwiftUI

/// Guia de otimização com ajustes REAIS que reduzem a latência percebida.
/// Nada de "módulos" falsos: são configurações do iOS que impactam de verdade.
struct OptimizationGuideView: View {
    var body: some View {
        NavigationView {
            List {
                Section {
                    Label(
                        "iOS não permite que apps de terceiros alterem a taxa de amostragem da tela ou o divisor de toque do sistema. O que este app faz é MEDIR sua latência e indicar os ajustes que comprovadamente reduzem o delay. Quem promete 'aumentar a sensibilidade do toque' por software no iPhone está vendendo placebo.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                Section("🔥 Maior impacto — faça primeiro") {
                    TipRow(
                        title: "Desligue o Modo de Pouca Energia",
                        detail: "Ajustes → Bateria. Ele reduz o teto de FPS do aparelho inteiro e adiciona input lag. É o ajuste nº 1 para jogos.",
                        icon: "battery.25", color: .orange
                    )
                    TipRow(
                        title: "Diminuir Movimento: LIGADO (com truque)",
                        detail: "Ajustes → Acessibilidade → Movimento → Diminuir Movimento: ON, e depois ATIVE também 'Auto-reproduzir mensagens de vídeo: OFF' e os toggles de 'Efeitos de plano de fundo'. Isso corta animações do sistema e o conteúdo chega mais rápido. Acelera sensação geral do aparelho.",
                        icon: "arrow.left.arrow.right.circle", color: .blue
                    )
                    TipRow(
                        title: "Ative o modo 120 Hz (ProMotion)",
                        detail: "Só iPhone Pro. Ajustes → Acessibilidade → Movimento → Limite de Quadros: Desativado. Se o jogo não é fluido em 120, limite para 60 — estabilidade vale mais que número alto.",
                        icon: "display", color: .purple
                    )
                    TipRow(
                        title: "Feche TODOS os apps em segundo plano",
                        detail: "Troque de app e feche tudo antes de jogar. RAM livre evita o sistema recarregar o jogo do zero quando ele é suspenso.",
                        icon: "xmark.app", color: .red
                    )
                }

                Section("🎮 Jogos — input lag") {
                    TipRow(
                        title: "Reduza a qualidade gráfica e suba o FPS nas configs do JOGO",
                        detail: "Dentro do jogo: FoV alto e gráficos baixos → mais FPS → menos delay por quadro. Delay de toque real = tempo até o PRÓXIMO quadro renderizar. 120 FPS = input lido a cada 8 ms; 30 FPS = a cada 33 ms.",
                        icon: "gamecontroller", color: .green
                    )
                    TipRow(
                        title: "Procure o Modo de Jogo do iOS (se disponível)",
                        detail: "Em versões recentes do iOS, o Modo de Jogo reduz atividade em segundo plano e prioriza toque/Bluetooth automaticamente. Se o seu modelo tiver, deixe ativo nos jogos.",
                        icon: "trophy", color: .yellow
                    )
                    TipRow(
                        title: "Bluetooth: desligue fones/controles que não usa",
                        detail: "Cada dispositivo Bluetooth adiciona 20–100 ms de latência em áudio/entrada. Se joga com som, prefira fone com fio.",
                        icon: "antenna.radiowaves.left.and.right.slash", color: .blue
                    )
                }

                Section("🌐 Rede — reduz ping") {
                    TipRow(
                        title: "Wi-Fi 5 GHz em vez de 2,4 GHz",
                        detail: "5 GHz tem menos interferência e latência estável (1–5 ms até o roteador). 2,4 GHz sofre com micro-ondas e vizinhos. Teste as duas bandas com o teste de rede deste app.",
                        icon: "wifi", color: .green
                    )
                    TipRow(
                        title: "Fique perto do roteador e longe de paredes",
                        detail: "Cada parede multiplica retransmissões. Se o ping até o roteador (teste com o IP dele aqui no app) já for >10 ms, o problema é o sinal, não a operadora.",
                        icon: "dot.radiowaves.left.and.right", color: .blue
                    )
                    TipRow(
                        title: "Pare de baixar/atualizar antes de jogar",
                        detail: "Downloads em segundo plano causam picos de bufferbloat (ping sobe 100+ ms). Pause tudo em Ajustes → Geral → Atualização em Segundo Plano.",
                        icon: "arrow.down.circle", color: .orange
                    )
                }

                Section("🔋 Sustentação — evite throttling") {
                    TipRow(
                        title: "Tire a capinha antes de jogar",
                        detail: "O calor fica retido e dispara o throttling térmico (veja o estado térmico na aba Desempenho). Sem capinha = FPS estável por mais tempo.",
                        icon: "thermometer.sun", color: .red
                    )
                    TipRow(
                        title: "Carregando? Jogue só com carregador de potência alta e sem capinha",
                        detail: "Carregar enquanto joga aquece o dobro. Se precisar, use carregador com boa potência para o aparelho priorizar energia em vez de poupar bateria.",
                        icon: "bolt.badge.clock", color: .yellow
                    )
                    TipRow(
                        title: "Reduza brilho para 50–70%",
                        detail: "Brilho máximo em OLED aquece o aparelho e acelera throttling. 50% é o ponto ideal entre visibilidade e temperatura.",
                        icon: "sun.min", color: .orange
                    )
                    TipRow(
                        title: "Reinicie o iPhone antes de sessões longas",
                        detail: "Semana sem reiniciar = processos zumbis acumulando RAM. Reiniciar limpa tudo e dá o melhor estado possível para o jogo.",
                        icon: "arrow.clockwise.circle", color: .blue
                    )
                }

                Section("❌ Mitos (não perca tempo)") {
                    Label("Apps 'turbo' da App Store — iOS isola cada app; nenhum app acelera outro.", systemImage: "xmark.circle")
                    Label("Limpar RAM manualmente — iOS gerencia sozinho e melhor que apps.", systemImage: "xmark.circle")
                    Label("VPNs 'anti-lag' — VPN adiciona um salto extra, nunca remove.", systemImage: "xmark.circle")
                    Label("Fechar apps CONSTANTEMENTE — recarregar um app gasta mais energia que mantê-lo suspenso.", systemImage: "xmark.circle")
                }
            }
            .navigationTitle("Otimizar")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

struct TipRow: View {
    let title: String
    let detail: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
