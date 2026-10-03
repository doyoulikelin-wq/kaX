import SwiftUI

@main
struct KaXApp: App {
    @State private var store: AppStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--uitesting") {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kax-ui-tests.json")
            if arguments.contains("--reset-data") { try? FileManager.default.removeItem(at: url) }
            _store = State(initialValue: AppStore(repository: LocalAppRepository(url: url)))
        } else {
            _store = State(initialValue: AppStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(KaXTheme.accent)
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--uitesting-dark") ? .dark : nil)
        }
    }
}
