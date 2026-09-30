# TouchBoost 🎯⚡

App iOS (SwiftUI) que **mede a latência real de toque do seu iPhone** e guia você pelos ajustes que **comprovadamente reduzem o delay** em jogos — além de monitor de FPS/RAM/temperatura, teste háptico, teste multi-touch e teste de ping com jitter.

## ⚠️ A parte honesta (leia antes de tudo)

O iOS **não permite** que nenhum app de terceiros:

- ❌ Aumente a taxa de amostragem da tela (o digitalizador do iPhone Pro já reporta toque a 120 Hz; nos modelos de 60 Hz, o divisor é fixo em hardware/firmware);
- ❌ Injete respostas de toque mais rápido no sistema (o app não fica no caminho do evento de toque);
- ❌ Forçar outros apps a rodarem com mais FPS (cada app roda isolado no sandbox).

Qualquer app/IPA que promete isso é **placebo** — ou pior, um tweak de jailbreak disfarçado que pode derrubar apps. O TouchBoost é diferente: ele **mede** a sua latência real, **monitora** o que está derrubando seu FPS (térmico, bateria, RAM) e **ensina** os ajustes do iOS que realmente reduzem o input lag percebido (Modo de Pouca Energia, Diminuir Movimento, ProMotion, Wi-Fi 5 GHz, etc.).

## ✅ O que o app faz de verdade

| Aba | Função |
|---|---|
| **Latência** | Taconômetro de toque: mede o intervalo real entre press e release, com mínimo/média/P95/máximo e vibração a cada toque (CoreHaptics). |
| **Toque/Háptico** | Teste o motor háptico com eventos transient/contínuos, sliders de intensidade/nitidez e presets de jogo (clique de disparo, recarga). |
| **Multi-touch** | Desenha cada dedo na tela e conta toques simultâneos/total — bom para testar se a tela está "engolindo" toques. |
| **Desempenho** | FPS ao vivo via CADisplayLink (detecta 60/120 Hz), memória real (phys_footprint), estado térmico e alerta de Modo de Pouca Energia. |
| **Rede** | Ping ICMP contínuo (Network.framework) com mínimo/média/máximo/jitter/perda — teste até o roteador e até a internet. |
| **Otimizar** | Guia com os ajustes reais do iOS, ordenados por impacto, + lista de mitos. |

## 🛠️ Como gerar a IPA (2 opções)

### Opção A — GitHub Actions (sem Mac) ← recomendado

1. Crie um repositório no GitHub e suba estes arquivos (`git push`);
2. Vá em **Actions → Build IPA → Run workflow**;
3. Em ~5 minutos, baixe o artefato **`TouchBoost-unsigned-ipa`** (contém `TouchBoost-unsigned.ipa`);
4. **Assine e instale** no iPhone (iOS exige assinatura válida), escolha UMA opção:
   - **Sideloadly** (Windows/Mac, gratuito): conecte o iPhone, abra o `.ipa` no Sideloadly, entre com seu Apple ID → instala em 2 min. Vale por 7 dias (reassine quando expirar); com conta paga de desenvolvedor, vale 1 ano.
   - **AltStore/SideStore**: instale o AltServer no PC, envie o AltStore pro iPhone, e instale o `.ipa` pelo AltStore. Reassina automaticamente em rede known.
   - **Apple Developer Program pago (US$ 99/ano)**: use [esign](https://esign.yerlands.com) ou Xcode para assinar com seu certificado — sem limite de 7 dias e sem precisar de PC depois.

### Opção B — Xcode no Mac

```bash
brew install xcodegen
xcodegen generate
open TouchBoost.xcodeproj
# No Xcode: selecione o target TouchBoost → Signing & Capabilities → seu Team → Run (⌘R) no iPhone
# Para gerar IPA: Product → Archive → Distribute App → Ad Hoc/Development
```

## 📱 Requisitos

- iPhone ou iPad com **iOS 15 ou superior**
- Conta Apple gratuita (para assinatura de 7 dias) ou paga (1 ano)

## 🧱 Estrutura

```
TouchBoost/
├── TouchBoostApp.swift      # Entry point + TabView
├── Tachometer.swift         # Taconômetro de latência de toque
├── HapticsTester.swift      # Teste do motor háptico
├── MultiTouchTest.swift     # Teste multi-touch
├── PerformanceMonitor.swift # FPS, RAM, térmico, Pouca Energia
├── NetworkTest.swift        # Ping ICMP com jitter/perda
└── OptimizationGuide.swift  # Guia de otimização real
project.yml                  # Definição do projeto (XcodeGen)
.github/workflows/build-ipa.yml  # Build automático da IPA
```

## 📜 Licença

Uso livre. Sem garantias — meça, ajuste, jogue melhor. 🎮
