import Foundation
import FuwaCore

func runKeyboardShortcutTests(runner: inout LogicTestRunner) {
    let standard = KeyboardShortcut.defaultPin
    runner.expect(standard.keyCode == 35, "the default shortcut uses the P physical key")
    runner.expect(standard.keyLabel == "P", "the default shortcut has a readable P label")
    runner.expect(
        standard.modifiers == [.option, .command],
        "the default shortcut uses Option and Command"
    )
    runner.expect(standard.displayString == "⌥⌘P", "the default shortcut renders as ⌥⌘P")
    runner.expect(standard.validationError == nil, "the default shortcut is valid")

    do {
        let data = try JSONEncoder().encode(standard)
        let decoded = try JSONDecoder().decode(KeyboardShortcut.self, from: data)
        runner.expect(decoded == standard, "shortcut settings survive a Codable round trip")
    } catch {
        runner.expect(false, "the default shortcut should be Codable: \(error)")
    }

    let noPrimaryModifier = KeyboardShortcut(
        keyCode: 35,
        keyLabel: "P",
        modifiers: [.shift]
    )
    runner.expect(
        noPrimaryModifier.validationError == .requiresPrimaryModifier,
        "Shift alone is rejected so Fuwa does not capture ordinary typing"
    )

    let unsupportedModifier = KeyboardShortcut(
        keyCode: 35,
        keyLabel: "P",
        modifiers: .init(rawValue: 1 << 7)
    )
    runner.expect(
        unsupportedModifier.validationError == .unsupportedModifiers(rawValue: 1 << 7),
        "unknown modifier bits are rejected"
    )

    let invalidKeyCode = KeyboardShortcut(
        keyCode: 128,
        keyLabel: "P",
        modifiers: [.command]
    )
    runner.expect(
        invalidKeyCode.validationError == .keyCodeOutOfRange(128),
        "key codes outside the macOS virtual-key range are rejected"
    )

    let blankLabel = KeyboardShortcut(
        keyCode: 35,
        keyLabel: "  ",
        modifiers: [.command]
    )
    runner.expect(blankLabel.validationError == .emptyKeyLabel, "blank shortcut labels are rejected")

    let proposed = KeyboardShortcut(
        keyCode: 49,
        keyLabel: "Space",
        modifiers: [.control, .option]
    )
    do {
        let update = try KeyboardShortcutUpdate(previous: standard, proposed: proposed)
        runner.expect(update.committedValue == proposed, "a registered shortcut commits the proposed value")
        runner.expect(
            update.rolledBackValue == standard,
            "a registration conflict restores the exact previous value"
        )
        runner.expect(
            update.resolvedValue(after: .registered) == proposed,
            "a successful registration resolves to the candidate"
        )
        runner.expect(
            update.resolvedValue(after: .conflict) == standard,
            "a conflicting registration resolves atomically to the previous shortcut"
        )
        runner.expect(
            update.resolvedValue(after: .inactive) == standard,
            "an inactive registration keeps the previous shortcut as an editable candidate"
        )
        runner.expect(
            standard == KeyboardShortcut.defaultPin,
            "constructing an update never mutates the current shortcut"
        )
    } catch {
        runner.expect(false, "a valid shortcut update should be constructible: \(error)")
    }

    do {
        _ = try KeyboardShortcutUpdate(previous: standard, proposed: blankLabel)
        runner.expect(false, "an invalid proposal cannot start a shortcut update")
    } catch let error as KeyboardShortcut.ValidationError {
        runner.expect(error == .emptyKeyLabel, "shortcut updates preserve typed validation errors")
    } catch {
        runner.expect(false, "invalid updates should use KeyboardShortcut.ValidationError")
    }
}
