import AppKit
import SwiftUI

struct FuwaPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary)
            }
            .opacity(opacity(isPressed: configuration.isPressed))
            .contentShape(Rectangle())
    }

    private func opacity(isPressed: Bool) -> Double {
        guard isEnabled else { return 0.35 }
        return isPressed ? 0.72 : 1
    }
}

struct FuwaQuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            }
            .opacity(isEnabled ? 1 : 0.35)
    }
}

struct FuwaIconButton: View {
    @ScaledMetric(relativeTo: .body) private var buttonWidth = 26
    @ScaledMetric(relativeTo: .body) private var buttonHeight = 24

    let symbol: String
    let label: String
    let isBusy: Bool
    let action: () -> Void

    init(
        symbol: String,
        label: String,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.label = label
        self.isBusy = isBusy
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isBusy {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: symbol)
                        .font(.body.weight(.medium))
                }
            }
            .frame(width: buttonWidth, height: buttonHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(label)
        .accessibilityLabel(label)
    }
}

struct FuwaNoticeView: View {
    @ScaledMetric(relativeTo: .body) private var dismissButtonSize = 18

    let notice: FuwaNotice
    let copy: FuwaCopy
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: notice.kind == .error ? "exclamationmark.circle" : "info.circle")
                .foregroundStyle(notice.kind == .error ? Color.red : Color.secondary)
                .accessibilityHidden(true)

            Text(notice.message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .frame(width: dismissButtonSize, height: dismissButtonSize)
            }
            .buttonStyle(.borderless)
            .help(copy.text(.dismiss))
            .accessibilityLabel(copy.text(.dismiss))
        }
        .padding(9)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

@MainActor
struct FuwaApplicationIcon: View {
    @ScaledMetric(relativeTo: .body) private var iconSize = 30

    let bundleIdentifier: String?
    let applicationName: String

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: iconSize, height: iconSize)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        if
            let bundleIdentifier,
            let applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
            )
        {
            return NSWorkspace.shared.icon(forFile: applicationURL.path)
        }

        if
            let runningIcon = NSWorkspace.shared.runningApplications
                .first(where: { $0.localizedName == applicationName })?
                .icon
        {
            return runningIcon
        }

        return NSImage(
            systemSymbolName: "macwindow",
            accessibilityDescription: applicationName
        ) ?? NSImage(size: NSSize(width: 30, height: 30))
    }
}

struct FuwaPermissionLabel: View {
    let state: FuwaPermissionState
    let copy: FuwaCopy

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(state == .denied ? Color.orange : Color.secondary)
            .accessibilityLabel(title)
    }

    private var title: String {
        switch state {
        case .unknown:
            copy.text(.permissionUnknown)
        case .granted:
            copy.text(.ready)
        case .denied:
            copy.text(.permissionNeeded)
        }
    }

    private var symbol: String {
        switch state {
        case .unknown:
            "minus.circle"
        case .granted:
            "checkmark.circle"
        case .denied:
            "exclamationmark.circle"
        }
    }
}
