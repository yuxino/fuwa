import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalHotKey {
    enum RegistrationError: LocalizedError {
        case installHandler(OSStatus)
        case registerHotKey(OSStatus)

        var errorDescription: String? {
            switch self {
            case .installHandler(let status):
                "无法安装快捷键事件处理器（\(status)）"
            case .registerHotKey(let status):
                "无法注册 ⌥⌘P（\(status)），可能与其他软件冲突"
            }
        }
    }

    private static let signature: OSType = 0x5750_4E44 // WPND
    private static let identifier: UInt32 = 1

    private let action: () -> Void
    private var hotKeyReference: EventHotKeyRef?
    private var handlerReference: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func start() throws {
        guard hotKeyReference == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }

                var identifier = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )

                guard
                    parameterStatus == noErr,
                    identifier.signature == GlobalHotKey.signature,
                    identifier.id == GlobalHotKey.identifier
                else {
                    return OSStatus(eventNotHandledErr)
                }

                let hotKey = Unmanaged<GlobalHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                MainActor.assumeIsolated {
                    hotKey.action()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerReference
        )

        guard handlerStatus == noErr else {
            throw RegistrationError.installHandler(handlerStatus)
        }

        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(cmdKey | optionKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKeyReference
        )

        guard registerStatus == noErr else {
            stop()
            throw RegistrationError.registerHotKey(registerStatus)
        }
    }

    func stop() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        if let handlerReference {
            RemoveEventHandler(handlerReference)
            self.handlerReference = nil
        }
    }

    isolated deinit {
        stop()
    }
}
