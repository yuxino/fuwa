import FuwaCore
import SwiftUI

@MainActor
struct PinRowView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var detailsIndent = 40
    @ScaledMetric(relativeTo: .body) private var progressSize = 22
    let pin: PinSnapshot

    private var copy: FuwaCopy { model.copy }
    private var isBusy: Bool { model.busyPinIDs.contains(pin.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                FuwaApplicationIcon(
                    bundleIdentifier: pin.bundleIdentifier,
                    applicationName: pin.applicationName
                )

                VStack(alignment: .leading, spacing: 2) {
                    Button { model.showControls(pin.id) } label: {
                        Text(pin.windowTitle).padding(.horizontal, 4).padding(.vertical, 2)
                    }
                        .buttonStyle(FuwaRowButtonStyle())
                        .disabled(!pin.canShowControls)
                        .accessibilityHint(copy.text(.showControls))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .truncationMode(.middle)
                        .help(pin.windowTitle)

                    HStack(spacing: 5) {
                        Text(pin.applicationName)
                        Text("·")
                            .accessibilityHidden(true)
                        Text(stateTitle)
                    }
                    .font(.caption)
                    .foregroundStyle(stateIsFailure ? Color.red : Color.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 6)

                if isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: progressSize, height: progressSize)
                        .accessibilityLabel(stateTitle)
                }
            }

            PinActionsView(model: model, pin: pin)
                .padding(.leading, detailsIndent)

            if let detailMessage {
                Text(detailMessage)
                    .font(.caption)
                    .foregroundStyle(stateIsFailure ? Color.red : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, detailsIndent)
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(pin.applicationName), \(pin.windowTitle), \(stateTitle)")
    }

    private var stateTitle: String { pin.stateTitle(copy) }

    private var stateIsFailure: Bool {
        if case .failed = pin.state { return true }
        return false
    }

    private var detailMessage: String? {
        if let errorMessage = pin.errorMessage, !errorMessage.isEmpty {
            return errorMessage
        }
        if case .unavailable(let message) = model.interactionStates[pin.id] {
            return message
        }
        return nil
    }
}
