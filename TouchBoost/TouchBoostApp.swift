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
    var body: some View {
        TabView {
            TurboView()
                .tabItem { Label("Turbo", systemImage: "bolt.fill") }
            TachometerView()
                .tabItem { Label("Latência", systemImage: "hand.tap.fill") }
            HapticsTesterView()
                .tabItem { Label("Toque/Háptico", systemImage: "iphone.radiowaves.left.and.right") }
            MultiTouchTestView()
                .tabItem { Label("Multi-touch", systemImage: "hand.point.up.left.fill") }
            PerformanceMonitorView()
                .tabItem { Label("Desempenho", systemImage: "gauge.high") }
            NetworkTestView()
                .tabItem { Label("Rede", systemImage: "wifi") }
            OptimizationGuideView()
                .tabItem { Label("Otimizar", systemImage: "slider.horizontal.3") }
        }
        .tint(.green)
    }
}
