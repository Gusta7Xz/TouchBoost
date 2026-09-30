import SwiftUI

/// Teste de multi-touch: desenha cada dedo na tela em tempo real e informa
/// quantos toques simultâneos o aparelho está registrando.
final class MultiTouchModel: ObservableObject {
    @Published var activeTouches = 0
    @Published var maxSimultaneous = 0
    @Published var totalTouches = 0
    @Published var touches: [TouchDot] = []
}

struct TouchDot: Identifiable {
    let id: Int // hash do UITouch
    var x: CGFloat
    var y: CGFloat
}

final class TouchTrackingView: UIView {
    var onUpdate: (([TouchDot], Int, Int, Int) -> Void)? // dots, active, max, total
    private var touchDates: [UITouch: Date] = [:]
    private(set) var maxSimultaneous = 0
    private(set) var totalTouches = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        for t in touches {
            touchDates[t] = Date()
            totalTouches += 1
        }
        maxSimultaneous = max(maxSimultaneous, touchDates.count)
        report()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        report()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        for t in touches { touchDates.removeValue(forKey: t) }
        report()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        for t in touches { touchDates.removeValue(forKey: t) }
        report()
    }

    func resetStats() {
        maxSimultaneous = 0
        totalTouches = 0
        report()
    }

    private func report() {
        let dots = touchDates.keys.map { touch -> TouchDot in
            let p = touch.location(in: self)
            return TouchDot(id: touch.hashValue, x: p.x, y: p.y)
        }
        onUpdate?(dots, touchDates.count, maxSimultaneous, totalTouches)
    }
}

struct MultiTouchCanvas: UIViewRepresentable {
    let model: MultiTouchModel

    func makeUIView(context: Context) -> TouchTrackingView {
        let v = TouchTrackingView()
        v.isMultipleTouchEnabled = true
        v.backgroundColor = UIColor.systemBackground
        v.onUpdate = { dots, active, maxS, total in
            DispatchQueue.main.async {
                model.touches = dots
                model.activeTouches = active
                model.maxSimultaneous = maxS
                model.totalTouches = total
            }
        }
        return v
    }

    func updateUIView(_ uiView: TouchTrackingView, context: Context) {}
}

struct MultiTouchTestView: View {
    @StateObject private var model = MultiTouchModel()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                countersHeader
                touchArea
            }
            .navigationTitle("Multi-touch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zerar") {
                        model.maxSimultaneous = 0
                        model.totalTouches = 0
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var countersHeader: some View {
        HStack {
            counterCard("Ativos", model.activeTouches, color: .green)
            counterCard("Máx. simult.", model.maxSimultaneous, color: .blue)
            counterCard("Total", model.totalTouches, color: .orange)
        }
        .padding()
    }

    private var touchArea: some View {
        ZStack {
            MultiTouchCanvas(model: model)
            touchDots
            emptyState
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var touchDots: some View {
        ForEach(model.touches) { dot in
            TouchDotView(dot: dot)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.activeTouches == 0 {
            Text("Coloque vários dedos na tela\n(e arraste-os) para testar")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    private func counterCard(_ label: String, _ value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.title2.monospacedDigit().bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

/// Círculo que representa um dedo na tela (extraído p/ aliviar o type-checker).
struct TouchDotView: View {
    let dot: TouchDot

    var body: some View {
        Circle()
            .fill(Color.green.opacity(0.55))
            .frame(width: 72, height: 72)
            .position(dot.x, dot.y)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .position(dot.x, dot.y)
            )
    }
}
