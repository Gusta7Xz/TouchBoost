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
    @AppStorage("boost.immersiveScreen") private var immersiveScreen = false
    @AppStorage("boost.zeroAnimations") private var zeroAnimations = false

    var body: some View {
        TabView {
            TurboView()
                .tabItem { Label("Turbo", systemImage: "bolt.fill") }
            TachometerView()
                .tabItem { Label("Latência", systemImage: "hand.tap.fill") }
            PerformanceMonitorView()
                .tabItem { Label("Desempenho", systemImage: "gauge.high") }
            NetworkTestView()
                .tabItem { Label("Rede", systemImage: "wifi") }
            OptimizationGuideView()
                .tabItem { Label("Otimizar", systemImage: "slider.horizontal.3") }
        }
        .tint(.green)
        .statusBar(hidden: immersiveScreen)
        .onAppear {
            UIView.setAnimationsEnabled(!zeroAnimations)
        }
        .onChange(of: zeroAnimations) { disabled in
            UIView.setAnimationsEnabled(!disabled)
        }
    }
}
