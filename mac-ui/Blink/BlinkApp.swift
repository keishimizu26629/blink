import AppKit
import Carbon
import SwiftUI

private extension BringToFrontShortcut {
    var keyEquivalent: KeyEquivalent {
        .space
    }

    var eventModifiers: SwiftUI.EventModifiers {
        switch self {
        case .shiftOptionSpace:
            [.shift, .option]
        case .commandShiftSpace:
            [.command, .shift]
        case .commandOptionSpace:
            [.command, .option]
        case .controlOptionSpace:
            [.control, .option]
        }
    }

    var keyCode: UInt32 {
        UInt32(kVK_Space)
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .shiftOptionSpace:
            UInt32(shiftKey | optionKey)
        case .commandShiftSpace:
            UInt32(cmdKey | shiftKey)
        case .commandOptionSpace:
            UInt32(cmdKey | optionKey)
        case .controlOptionSpace:
            UInt32(controlKey | optionKey)
        }
    }
}

@main
struct BlinkApp: App {
    @FocusedValue(\.projectViewModel) private var focusedProjectViewModel

    init() {
        BringToFrontHotkeyManager.shared.start()
    }

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
            CommandGroup(after: .windowArrangement) {
                Button("最前面に表示") {
                    toggleBringToFrontVisibility()
                }
                .keyboardShortcut(
                    focusedProjectViewModel?.bringToFrontShortcut.keyEquivalent ?? .space,
                    modifiers: focusedProjectViewModel?.bringToFrontShortcut.eventModifiers ?? [.shift, .option]
                )
                .disabled(!(focusedProjectViewModel?.isBringToFrontHotkeyEnabled ?? true))

                Button(
                    focusedProjectViewModel?.isBringToFrontHotkeyEnabled == true
                        ? "最前面ショートカットを無効化"
                        : "最前面ショートカットを有効化"
                ) {
                    focusedProjectViewModel?.toggleBringToFrontHotkeyEnabled()
                }
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

    private func toggleBringToFrontVisibility() {
        if NSApp.isActive {
            NSApp.hide(nil)
            return
        }

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.windows.isEmpty {
            NSApp.keyWindow?.makeKeyAndOrderFront(nil)
            NSApp.mainWindow?.makeKeyAndOrderFront(nil)
        } else {
            NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }
}

private final class BringToFrontHotkeyManager {
    static let shared = BringToFrontHotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var observer: NSObjectProtocol?
    private var isStarted = false

    private init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true

        installEventHandlerIfNeeded()
        observer = NotificationCenter.default.addObserver(
            forName: ProjectViewModel.bringToFrontSettingsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadRegistration()
        }
        reloadRegistration()
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        unregisterHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            Self.hotKeyEventHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
        guard status == noErr else {
            eventHandlerRef = nil
            return
        }
    }

    private func reloadRegistration() {
        unregisterHotKey()

        let defaults = UserDefaults.standard
        let isEnabled: Bool = if defaults.object(forKey: "blink.window.bringToFront.hotkey.enabled") == nil {
            true
        } else {
            defaults.bool(forKey: "blink.window.bringToFront.hotkey.enabled")
        }
        guard isEnabled else { return }

        let shortcutRaw = defaults.string(forKey: "blink.window.bringToFront.hotkey.shortcut") ?? ""
        let shortcut = BringToFrontShortcut(rawValue: shortcutRaw) ?? .shiftOptionSpace

        var hotKeyID = EventHotKeyID(signature: Self.signature, id: 1)
        var newRef: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &newRef
        )
        if registerStatus == noErr {
            hotKeyRef = newRef
        } else {
            hotKeyRef = nil
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func handleHotKeyPressed() {
        DispatchQueue.main.async {
            if NSApp.isActive {
                NSApp.hide(nil)
                return
            }

            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            if NSApp.windows.isEmpty {
                NSApp.keyWindow?.makeKeyAndOrderFront(nil)
                NSApp.mainWindow?.makeKeyAndOrderFront(nil)
            } else {
                NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
            }
        }
    }

    private static let signature: FourCharCode = {
        let chars: [UInt8] = Array("BLNK".utf8)
        return chars.reduce(0) { partialResult, char in
            (partialResult << 8) + FourCharCode(char)
        }
    }()

    private static let hotKeyEventHandler: EventHandlerUPP = { _, eventRef, userData in
        guard let eventRef, let userData else { return noErr }
        let manager = Unmanaged<BringToFrontHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        if status == noErr, hotKeyID.signature == BringToFrontHotkeyManager.signature {
            manager.handleHotKeyPressed()
        }
        return noErr
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
