import AppKit
import SwiftUI

@MainActor
struct MainView: View {
    @ObservedObject var model: AppModel
    @State private var choosingWindow = false
    @State private var settingsSelected = false
    private var copy: FuwaCopy { model.copy }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 38, height: 38)
                        .accessibilityHidden(true)
                    Text("Fuwa").font(.title2.weight(.semibold))
                }
                VStack(spacing: 6) {
                    navigation(copy.text(.pins), symbol: "pin", selected: !settingsSelected) {
                        settingsSelected = false
                    }
                    navigation(copy.text(.settings), symbol: "gearshape", selected: settingsSelected) {
                        settingsSelected = true
                    }
                }
                Spacer()
                Text(copy.pinsCount(model.pins.count))
                    .font(.caption).foregroundStyle(.secondary)
                Text("\(copy.text(.version)) \(model.version)")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(width: 174)
            .frame(maxHeight: .infinity)
            .background(Color.primary.opacity(0.025))
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(copy.text(settingsSelected ? .settings : .manageWindows))
                            .font(.title2.weight(.semibold))
                        Spacer()
                        if !settingsSelected {
                            Button { choosingWindow = true } label: {
                                Label(copy.text(.chooseWindow), systemImage: "plus")
                            }
                            .buttonStyle(FuwaQuietButtonStyle())
                            .disabled(model.isPinningFrontWindow || model.isClearingAll)
                        }
                    }
                    if !settingsSelected {
                        Text(copy.text(.noPinsBody))
                            .font(.callout).foregroundStyle(.secondary)
                        Text(model.shortcutIsActive ? model.shortcut.displayString : copy.text(.shortcutInactive))
                            .font(.system(.callout, design: .monospaced).weight(.medium))
                            .textSelection(.enabled)
                    }
                }
                .padding(24)
                if let notice = model.notice {
                    FuwaNoticeView(notice: notice, copy: copy, onDismiss: model.dismissNotice)
                        .padding(.horizontal, 24).padding(.bottom, 16)
                }
                Divider()
                if settingsSelected {
                    SettingsView(model: model)
                } else {
                    PinsView(model: model, showsPinAction: false)
                    Spacer(minLength: 0)
                    Divider()
                    HStack {
                        Text(copy.text(.removeExplanation))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(copy.text(.clearAll), action: model.clearAll)
                            .disabled(model.pins.isEmpty || model.isClearingAll)
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $choosingWindow) { WindowPickerView(model: model) }
    }

    private func navigation(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.body.weight(selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(selected ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
