import SwiftUI

@main
struct UrkelBirdDemoApp: App {
    var body: some Scene {
        WindowGroup("UrkelBird Demo") {
            UrkelBirdGameView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
    }
}
