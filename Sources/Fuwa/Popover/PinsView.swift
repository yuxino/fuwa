import SwiftUI

@MainActor
struct PinsView: View {
    @ObservedObject var model: AppModel
    @FocusState private var pinButtonFocused: Bool
    @ScaledMetric(relativeTo: .body) private var rowDividerIndent = 54

    private var copy: FuwaCopy { model.copy }

    var body: some View {
        VStack(spacing: 0) {
            pinButton
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            if !model.pins.isEmpty {
                Divider()
                pinsList
            }
        }
        .onAppear {
            pinButtonFocused = true
        }
    }

    private var pinButton: some View {
        Button(action: model.pinFrontWindow) {
            HStack(spacing: 7) {
                if model.isPinningFrontWindow {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color(nsColor: .windowBackgroundColor))
                } else {
                    Image(systemName: "pin")
                        .accessibilityHidden(true)
                }

                Text(pinButtonTitle)

                Spacer(minLength: 8)

                Text(model.shortcut.displayString)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .opacity(model.shortcutIsActive ? 0.72 : 0.35)
            }
        }
        .buttonStyle(FuwaPrimaryButtonStyle())
        .disabled(model.isPinningFrontWindow)
        .focused($pinButtonFocused)
        .help(pinButtonHint)
        .accessibilityLabel(pinButtonTitle)
        .accessibilityValue(
            model.shortcutIsActive
                ? model.shortcut.displayString
                : copy.text(.shortcutInactive)
        )
        .accessibilityHint(pinButtonHint)
    }

    private var pinsList: some View {
        VStack(spacing: 0) {
            HStack {
                Text(copy.text(.pins))
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(copy.pinsCount(model.pins.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.pins.enumerated()), id: \.element.id) { index, pin in
                        PinRowView(model: model, pin: pin)
                            .padding(.horizontal, 14)

                        if index < model.pins.count - 1 {
                            Divider()
                                .padding(.leading, rowDividerIndent)
                        }
                    }
                }
            }
            .scrollIndicators(.automatic)
        }
    }

    private var pinButtonTitle: String {
        model.isPinningFrontWindow ? copy.text(.pinning) : copy.text(.pinFrontWindow)
    }

    private var pinButtonHint: String {
        model.shortcutIsActive ? copy.text(.noPinsBody) : copy.text(.shortcutInactive)
    }
}
