import SwiftUI

@main
struct TouchBoostApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @AppStorage("touch.immersiveScreen") private var immersiveScreen = false
    @AppStorage("touch.instantResponse") private var instantResponse = false

    var body: some View {
        TabView {
            TouchTabView()
                .tabItem { Label("Toque", systemImage: "hand.tap.fill") }
            OptimizationTabView()
                .tabItem { Label("Otimização", systemImage: "bolt.circle.fill") }
            TachometerView()
                .tabItem { Label("Latência", systemImage: "speedometer") }
            PerformanceMonitorView()
                .tabItem { Label("Desempenho", systemImage: "gauge.high") }
            NetworkTestView()
                .tabItem { Label("Rede", systemImage: "wifi") }
            OptimizationGuideView()
                .tabItem { Label("Dicas", systemImage: "lightbulb") }
        }
        .tint(.green)
        .statusBar(hidden: immersiveScreen)
        .onAppear {
            UIView.setAnimationsEnabled(!instantResponse)
        }
        .onChange(of: instantResponse) { disabled in
            UIView.setAnimationsEnabled(!disabled)
        }
    }
}
