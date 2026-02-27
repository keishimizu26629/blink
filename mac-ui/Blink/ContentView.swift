import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: ProjectViewModel

    var body: some View {
        NavigationSplitView {
            ProjectTreeView(
                nodes: viewModel.rootNodes,
                selectedFileId: viewModel.selectedFile?.id,
                onSelectFile: { node in
                    Task {
                        await viewModel.selectFile(node: node)
                    }
                },
                onToggleDir: { node in
                    Task {
                        await viewModel.toggleDir(node: node)
                    }
                }
            )
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 400)
        } detail: {
            if let content = viewModel.fileContent {
                HStack(spacing: 0) {
                    if viewModel.isBlameVisible {
                        ScrollView(.vertical, showsIndicators: false) {
                            BlameGutterView(blameLines: viewModel.blameLines)
                        }
                        .frame(width: 130)

                        Divider()
                    }

                    CodeTextView(text: content, tokens: viewModel.highlightTokens)
                }
            } else {
                Text("ファイルを選択してください")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.isBlameVisible.toggle()
                } label: {
                    Label(
                        "Blame",
                        systemImage: viewModel.isBlameVisible ? "person.fill" : "person"
                    )
                }
                .help("Git Blame の表示切替")
                .disabled(viewModel.fileContent == nil)
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
