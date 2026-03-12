import SwiftUI

@main
struct RelayApp: App {
    @State private var matrixService = MatrixService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.matrixService, matrixService)
        }
        .defaultSize(width: 900, height: 600)
    }
}
