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
                    Text(pin.windowTitle)
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

            HStack(spacing: 4) {
                Text(interactionTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if pin.canFreeze {
                    FuwaIconButton(
                        symbol: "pause.fill",
                        label: copy.text(.freeze),
                        action: { model.freeze(pin.id) }
                    )
                    .disabled(isBusy)
                } else if pin.canResume {
                    FuwaIconButton(
                        symbol: "play.fill",
                        label: copy.text(.resume),
                        action: { model.resume(pin.id) }
                    )
                    .disabled(isBusy)
                }

                FuwaIconButton(
                    symbol: interactionSymbol,
                    label: copy.text(.interact),
                    action: { model.interact(pin.id) }
                )
                .disabled(isBusy || !canUseSource)

                FuwaIconButton(
                    symbol: "arrow.up.forward.app",
                    label: copy.text(.revealSource),
                    action: { model.revealSource(pin.id) }
                )
                .disabled(isBusy || !canUseSource)

                FuwaIconButton(
                    symbol: "xmark",
                    label: copy.text(.unpin),
                    action: { model.unpin(pin.id) }
                )
                .disabled(isBusy)
            }
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

    private var stateTitle: String {
        switch pin.state {
        case .resolving:
            copy.text(.resolving)
        case .starting:
            copy.text(.starting)
        case .live:
            copy.text(.live)
        case .frozen(.manual):
            copy.text(.frozen)
        case .frozen(.sourceClosed):
            copy.text(.sourceClosed)
        case .frozen(.captureInterrupted):
            copy.text(.captureInterrupted)
        case .failed:
            copy.text(.failed)
        case .stopping, .stopped:
            copy.text(.stopping)
        }
    }

    private var stateIsFailure: Bool {
        if case .failed = pin.state { return true }
        return false
    }

    private var canUseSource: Bool {
        switch pin.state {
        case .live, .frozen(.manual), .frozen(.captureInterrupted):
            true
        case .resolving, .starting, .frozen(.sourceClosed), .failed, .stopping, .stopped:
            false
        }
    }

    private var interactionTitle: String {
        switch model.interactionStates[pin.id] ?? .viewOnly {
        case .viewOnly:
            copy.text(.viewOnly)
        case .engaged:
            copy.text(.interacting)
        case .unavailable:
            copy.text(.interactionUnavailable)
        }
    }

    private var interactionSymbol: String {
        switch model.interactionStates[pin.id] ?? .viewOnly {
        case .viewOnly, .unavailable:
            "cursorarrow.click"
        case .engaged:
            "cursorarrow.rays"
        }
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
