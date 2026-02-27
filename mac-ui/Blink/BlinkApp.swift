import SwiftUI

@main
struct BlinkApp: App {
    @StateObject private var viewModel = ProjectViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder…") {
                    openFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "プロジェクトフォルダを選択してください"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.openProject(path: url.path)
            }
        }
    }
}
