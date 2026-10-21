import SwiftUI

extension Notification.Name {
    /// Posted when the user asks for a reload (Cmd+R on Mac Catalyst).
    static let jmcReload = Notification.Name("JMCReloadGame")
}

@main
struct JantarMantarChaloApp: App {
    var body: some Scene {
        WindowGroup {
            GameWebView()
                .statusBarHidden(true)
                .ignoresSafeArea()
        }
        #if targetEnvironment(macCatalyst)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Reload Game") {
                    NotificationCenter.default.post(name: .jmcReload, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        #endif
    }
}
