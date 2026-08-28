import AppKit
import SwiftUI

enum FuwaPopoverLayout {
    static func isCompactEmpty(
        route: FuwaPopoverRoute,
        hasPins: Bool
    ) -> Bool {
        route == .pins && !hasPins
    }

    static func preferredContentSize(
        route: FuwaPopoverRoute,
        hasPins: Bool,
        hasNotice: Bool,
        hasPermissionWarning: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) -> NSSize {
        let compact = isCompactEmpty(
            route: route,
            hasPins: hasPins
        )

        if dynamicTypeSize >= .accessibility3 {
            return NSSize(
                width: 472,
                height: compact
                    ? (hasNotice ? 580 : 340) + (hasPermissionWarning ? 40 : 0)
                    : 720
            )
        }
        if dynamicTypeSize.isAccessibilitySize {
            return NSSize(
                width: 436,
                height: compact
                    ? (hasNotice ? 460 : 280) + (hasPermissionWarning ? 28 : 0)
                    : 660
            )
        }
        if dynamicTypeSize >= .xxLarge {
            return NSSize(
                width: 396,
                height: compact
                    ? (hasNotice ? 320 : 192) + (hasPermissionWarning ? 16 : 0)
                    : 600
            )
        }
        return NSSize(
            width: 364,
            height: compact ? (hasNotice ? 248 : 160) : 520
        )
    }
}

private struct FuwaPopoverLayoutSignature: Equatable {
    let route: FuwaPopoverRoute
    let hasPins: Bool
    let noticeID: UUID?
    let hasPermissionWarning: Bool
    let dynamicTypeSize: DynamicTypeSize
}

@MainActor
struct FuwaPopoverView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var navigationButtonSize = 24
    @ScaledMetric(relativeTo: .body) private var moreButtonWidth = 24
    @ScaledMetric(relativeTo: .body) private var moreButtonHeight = 20

    let onPreferredContentSizeChange: @MainActor (NSSize) -> Void

    private var copy: FuwaCopy { model.copy }

    init(
        model: AppModel,
        onPreferredContentSizeChange: @escaping @MainActor (NSSize) -> Void = { _ in }
    ) {
        _model = ObservedObject(wrappedValue: model)
        self.onPreferredContentSizeChange = onPreferredContentSizeChange
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let notice = model.notice {
                FuwaNoticeView(
                    notice: notice,
                    copy: copy,
                    onDismiss: model.dismissNotice
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .transition(reduceMotion ? .identity : .opacity)
            }

            Group {
                switch model.route {
                case .pins:
                    PinsView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: isCompactEmpty ? nil : .infinity
            )

            if model.route == .pins {
                Divider()
                footer
            }
        }
        .frame(
            minWidth: 320,
            idealWidth: preferredContentSize.width,
            maxWidth: .infinity,
            minHeight: isCompactEmpty ? 0 : 360,
            idealHeight: preferredContentSize.height,
            maxHeight: .infinity
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand(perform: model.dismissPopover)
        .onAppear(perform: reportPreferredContentSize)
        .onChange(of: layoutSignature) { _, _ in
            reportPreferredContentSize()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.text(.appName))
    }

    private var header: some View {
        HStack(spacing: 10) {
            if model.route == .settings {
                Button(action: model.showPins) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.semibold))
                        .frame(width: navigationButtonSize, height: navigationButtonSize)
                }
                .buttonStyle(.borderless)
                .help(copy.text(.back))
                .accessibilityLabel(copy.text(.back))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(model.route == .pins ? copy.text(.appName) : copy.text(.settings))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                if model.route == .pins {
                    Text(copy.text(.appTagline))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if model.route == .pins {
                Text(model.shortcut.displayString)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .opacity(model.shortcutIsActive ? 1 : 0.45)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.055))
                    }
                    .help(shortcutAccessibilityText)
                    .accessibilityLabel(shortcutAccessibilityText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button(action: model.showSettings) {
                HStack(spacing: 5) {
                    Image(
                        systemName: model.hasPermissionWarning
                            ? "exclamationmark.circle"
                            : "gearshape"
                    )
                    Text(
                        model.hasPermissionWarning
                            ? copy.text(.permissionAttention)
                            : copy.text(.settings)
                    )
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(model.hasPermissionWarning ? Color.orange : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(settingsButtonLabel)
            .accessibilityLabel(settingsButtonLabel)

            Spacer()

            if !model.pins.isEmpty {
                Button(action: model.clearAll) {
                    if model.isClearingAll {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Text(copy.text(.clearAll))
                            .font(.caption.weight(.medium))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(model.isClearingAll)
                .help(copy.text(.clearAll))
                .accessibilityLabel(copy.text(.clearAll))
            }

            Menu {
                Button(copy.text(.about), action: model.showAbout)
                Divider()
                Button(copy.text(.quit), action: model.quit)
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: moreButtonWidth, height: moreButtonHeight)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(copy.text(.moreActions))
            .accessibilityLabel(copy.text(.moreActions))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .frame(minHeight: 38)
    }

    private var settingsButtonLabel: String {
        model.hasPermissionWarning
            ? copy.text(.permissionAttention)
            : copy.text(.settings)
    }

    private var shortcutAccessibilityText: String {
        model.shortcutIsActive
            ? "\(copy.text(.shortcut)): \(model.shortcut.displayString)"
            : copy.text(.shortcutInactive)
    }

    private var preferredContentSize: NSSize {
        FuwaPopoverLayout.preferredContentSize(
            route: model.route,
            hasPins: !model.pins.isEmpty,
            hasNotice: model.notice != nil,
            hasPermissionWarning: model.hasPermissionWarning,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private var isCompactEmpty: Bool {
        FuwaPopoverLayout.isCompactEmpty(
            route: model.route,
            hasPins: !model.pins.isEmpty
        )
    }

    private var layoutSignature: FuwaPopoverLayoutSignature {
        FuwaPopoverLayoutSignature(
            route: model.route,
            hasPins: !model.pins.isEmpty,
            noticeID: model.notice?.id,
            hasPermissionWarning: model.hasPermissionWarning,
            dynamicTypeSize: dynamicTypeSize
        )
    }

    private func reportPreferredContentSize() {
        onPreferredContentSizeChange(preferredContentSize)
    }
}
