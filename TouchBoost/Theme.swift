import SwiftUI

// MARK: - Design System

enum TBTheme {
    static let accent = Color(red: 0.20, green: 0.98, blue: 0.55)
    static let accentDark = Color(red: 0.05, green: 0.55, blue: 0.32)
    static let bgGradientTop = Color(red: 0.02, green: 0.06, blue: 0.09)
    static let bgGradientBottom = Color(red: 0.00, green: 0.02, blue: 0.05)
    static let cardTop = Color(red: 0.07, green: 0.11, blue: 0.14)
    static let cardBottom = Color(red: 0.04, green: 0.07, blue: 0.10)
    static let heroGradient = LinearGradient(
        colors: [Color(red: 0.00, green: 0.36, blue: 0.22), Color(red: 0.02, green: 0.10, blue: 0.16)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let cardGradient = LinearGradient(
        colors: [cardTop, cardBottom],
        startPoint: .top, endPoint: .bottom
    )
    static let boltGradient = LinearGradient(
        colors: [Color(red: 0.4, green: 1.0, blue: 0.6), Color(red: 0.0, green: 0.85, blue: 0.45)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Card genérico

struct TBCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(TBTheme.cardGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Hero (cabeçalho com gradiente)

struct TBHero: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var stat1: (String, String)? = nil
    var stat2: (String, String)? = nil
    var stat3: (String, String)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TBTheme.boltGradient)
                        .frame(width: 46, height: 46)
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer()
            }

            if stat1 != nil || stat2 != nil || stat3 != nil {
                HStack(spacing: 10) {
                    if let s = stat1 { TBStat(value: s.0, label: s.1) }
                    if let s = stat2 { TBStat(value: s.0, label: s.1) }
                    if let s = stat3 { TBStat(value: s.0, label: s.1) }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(TBTheme.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

struct TBStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).bold())
                .foregroundColor(TBTheme.accent)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.28)))
    }
}

// MARK: - Linha de ajuste com slider

struct TBSliderRow: View {
    let title: String
    let detail: String
    let icon: String
    let iconColor: Color
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(iconColor.opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(Int(value))\(suffix)")
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundColor(TBTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(TBTheme.accent.opacity(0.12)))
            }
            Slider(value: $value, in: range, step: 5)
                .tint(TBTheme.accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TBTheme.cardGradient)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
}

// MARK: - Linha de toggle

struct TBToggleRow: View {
    let title: String
    let detail: String
    let icon: String
    let iconColor: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(TBTheme.accent)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TBTheme.cardGradient)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        )
    }
}

// MARK: - Botão de ação principal

struct TBPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(.headline, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(TBTheme.boltGradient)
                    .shadow(color: TBTheme.accent.opacity(0.35), radius: 14, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { p in pressed = p }, perform: {})
    }
}

// MARK: - Cabeçalho de seção

struct TBSectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(TBTheme.boltGradient)
                .frame(width: 3, height: 16)
                .cornerRadius(2)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.top, 6)
    }
}

// MARK: - ScrollView padrão das abas

struct TBScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(colors: [TBTheme.bgGradientTop, TBTheme.bgGradientBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}
