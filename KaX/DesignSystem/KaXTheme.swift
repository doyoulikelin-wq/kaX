import SwiftUI

enum KaXTheme {
    static let accent = Color("AccentColor")
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let line = Color(uiColor: .separator).opacity(0.25)
}

struct RoundedPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KaXTheme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 12)
            if let trailing { Text(trailing).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct OriginBadge: View {
    let origin: DataOrigin
    var body: some View {
        Text(origin.title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08), in: Capsule())
            .accessibilityLabel("数据来源：\(origin.title)")
    }
}

struct MetricValue: View {
    let value: String
    let unit: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value).font(.system(size: 36, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(unit).font(.subheadline).foregroundStyle(.secondary)
        }.minimumScaleFactor(0.6)
    }
}

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 40
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .semibold))
            .foregroundStyle(KaXTheme.accent)
            .frame(width: size, height: size)
            .background(KaXTheme.accent.opacity(0.10), in: Circle())
            .accessibilityHidden(true)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        }
    }
}

struct KaXPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(isEnabled ? KaXTheme.accent : Color.gray, in: RoundedRectangle(cornerRadius: 16))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension View {
    func pageWidth() -> some View {
        self.frame(maxWidth: 680).frame(maxWidth: .infinity)
    }
}
