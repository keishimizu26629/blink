import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: ProjectViewModel
    @State private var isFolderImporterPresented = false

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
            ZStack {
                Color(nsColor: SyntaxTheme.backgroundColor)
                    .ignoresSafeArea()

                if let content = viewModel.fileContent {
                    HStack(spacing: 0) {
                        if viewModel.isBlameVisible {
                            ScrollView(.vertical, showsIndicators: false) {
                                BlameGutterView(blameLines: viewModel.blameLines)
                            }
                            .frame(width: 130)

                            Divider()
                        }

                        CodeTextView(
                            text: Binding(
                                get: { viewModel.fileContent ?? content },
                                set: { viewModel.fileContent = $0 }
                            ),
                            tokens: viewModel.highlightTokens
                        )
                        .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("フォルダまたはファイルを選択してください")
                        .font(.title3)
                        .foregroundStyle(Color(nsColor: SyntaxTheme.defaultTextColor).opacity(0.9))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                    Slider(
                        value: Binding(
                            get: { viewModel.windowOpacity },
                            set: { viewModel.updateWindowOpacity($0) }
                        ),
                        in: 0.6 ... 1.0
                    )
                    .frame(width: 140)
                    Text("\(Int(viewModel.windowOpacity * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
                .help("ウィンドウ不透明度")
            }
        }
        .background(
            WindowOpacityConfigurator(opacity: viewModel.windowOpacity)
                .allowsHitTesting(false)
        )
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                Task {
                    await viewModel.openProject(url: url)
                }
            case let .failure(error):
                viewModel.errorMessage = "フォルダ選択に失敗しました: \(error.localizedDescription)"
            }
        }
        .alert("エラー", isPresented: errorPresentedBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func openFolder() {
        isFolderImporterPresented = true
    }

    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

private struct WindowOpacityConfigurator: NSViewRepresentable {
    let opacity: Double

    func makeNSView(context _: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            applyWindowOpacity(opacity, to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        DispatchQueue.main.async {
            applyWindowOpacity(opacity, to: nsView.window)
        }
    }

    private func applyWindowOpacity(_ opacity: Double, to window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = CGFloat(opacity)
    }
}
