import SwiftUI

@main
struct BlinkApp: App {
    @FocusedValue(\.projectViewModel) private var focusedProjectViewModel

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Folder…") {
                    openFolder(for: focusedProjectViewModel)
                }
                .keyboardShortcut("o", modifiers: [.command])
                .disabled(focusedProjectViewModel == nil)
            }
        }
    }

    private func openFolder(for viewModel: ProjectViewModel?) {
        guard let viewModel else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "プロジェクトフォルダを選択してください"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.openProject(url: url)
            }
        }
    }
}

private struct ProjectViewModelFocusedValueKey: FocusedValueKey {
    typealias Value = ProjectViewModel
}

extension FocusedValues {
    var projectViewModel: ProjectViewModel? {
        get { self[ProjectViewModelFocusedValueKey.self] }
        set { self[ProjectViewModelFocusedValueKey.self] = newValue }
    }
}
