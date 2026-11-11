import AppKit
import Carbon
import Combine
import ServiceManagement

enum GlobalShortcut: String, CaseIterable {
    case p, space, s
    var title: String { "⌃⌥⌘" + (self == .space ? "Space" : rawValue.uppercased()) }
    var keyCode: UInt32 {
        switch self {
        case .p: return UInt32(kVK_ANSI_P)
        case .space: return UInt32(kVK_Space)
        case .s: return UInt32(kVK_ANSI_S)
        }
    }
}

/// Registers only the selected combination; no keyboard monitoring or Accessibility access.
final class GlobalShortcutService: ObservableObject {
    @Published private(set) var error: String?
    @Published private(set) var registered = false
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onToggle: () -> Void = {}

    func configure(enabled: Bool, shortcut: GlobalShortcut) {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        registered = false
        error = nil
        guard enabled else {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            return
        }
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var identifier = EventHotKeyID()
                let result = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                              nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
                guard result == noErr, identifier.signature == 0x57575448, identifier.id == 1 else {
                    return OSStatus(eventNotHandledErr)
                }
                Unmanaged<GlobalShortcutService>.fromOpaque(context).takeUnretainedValue().onToggle()
                return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard status == noErr else { error = "단축키를 준비하지 못했습니다. (\(status))"; return }
        }
        let result = RegisterEventHotKey(shortcut.keyCode, UInt32(controlKey | optionKey | cmdKey),
                                        EventHotKeyID(signature: 0x57575448, id: 1), GetApplicationEventTarget(), 0, &hotKey)
        registered = result == noErr
        if !registered {
            if let handler { RemoveEventHandler(handler) }
            handler = nil
            error = "이 단축키를 등록할 수 없습니다. 다른 조합을 선택해 주세요. (\(result))"
        }
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

final class LoginItemService: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var error: String?
    private let available: Bool
    private var observer: NSObjectProtocol?

    init(available: Bool = true) {
        self.available = available
        refresh()
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                         object: nil, queue: .main) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        guard available else { return }
        let status = SMAppService.mainApp.status
        needsApproval = status == .requiresApproval
        enabled = status == .enabled || needsApproval
    }

    @discardableResult func setEnabled(_ requested: Bool) -> Bool {
        guard available else { return false }
        do {
            if requested { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            error = nil
            refresh()
            return enabled == requested
        } catch {
            self.error = "자동 실행 설정을 바꾸지 못했습니다: \(error.localizedDescription)"
            refresh()
            return false
        }
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
}
