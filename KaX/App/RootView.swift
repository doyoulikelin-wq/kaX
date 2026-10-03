import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            SocialFeedView()
                .tabItem { Label("动态", systemImage: "rectangle.stack") }
                .tag(0)
            MeasurementView()
                .tabItem { Label("测量", systemImage: "waveform.path") }
                .tag(1)
            RankingView()
                .tabItem { Label("排行", systemImage: "chart.bar.xaxis") }
                .tag(2)
            ProfileView()
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(3)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = store.persistenceError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.red)
                    .padding(10).frame(maxWidth: .infinity)
                    .background(.regularMaterial)
                    .accessibilityIdentifier("storageErrorBanner")
            }
        }
    }
}
