import AppKit
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import ScreenCaptureKit
import WindowPinCore

enum PinError: LocalizedError {
    case screenRecordingPermissionRequired
    case noUsableWindow
    case selectedWindowUnavailable

    var errorDescription: String? {
        switch self {
        case .screenRecordingPermissionRequired:
            "需要屏幕录制权限。请在系统设置中允许 WindowPinDemo，然后重新打开应用。"
        case .noUsableWindow:
            "没有找到可固定的前台窗口。请先点一下目标窗口，再按 ⌥⌘P。"
        case .selectedWindowUnavailable:
            "目标窗口无法被 ScreenCaptureKit 捕获。"
        }
    }
}

@MainActor
final class PinnedWindowController: NSObject, @preconcurrency SCStreamOutput, SCStreamDelegate {
    private(set) var isPinned = false
    private(set) var isTransitioning = false

    var onPinnedStateChange: ((Bool) -> Void)?
    var onFailure: ((String) -> Void)?

    private var panel: NSPanel?
    private var captureView: CaptureView?
    private var stream: SCStream?
    private var geometryTimer: Timer?
    private var resizeTask: Task<Void, Never>?
    private var targetWindowID: CGWindowID?
    private var captureScale: CGFloat = 2
    private var acceptsFrames = false

    func pinFrontmostWindow(ownerPID: pid_t) async throws {
        guard !isTransitioning, !isPinned else { return }
        isTransitioning = true
        defer { isTransitioning = false }

        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            throw PinError.screenRecordingPermissionRequired
        }

        let orderedWindows = WindowServer.orderedOnScreenWindows()
        guard let windowID = WindowSelector.firstCandidate(
            in: orderedWindows,
            ownerPID: ownerPID
        ) else {
            throw PinError.noUsableWindow
        }

        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let selectedWindow = shareableContent.windows.first(where: { $0.windowID == windowID }) else {
            throw PinError.selectedWindowUnavailable
        }

        let contentFilter = SCContentFilter(desktopIndependentWindow: selectedWindow)
        let configuration = makeConfiguration(
            pointSize: contentFilter.contentRect.size,
            pointScale: CGFloat(contentFilter.pointPixelScale)
        )
        let captureStream = SCStream(
            filter: contentFilter,
            configuration: configuration,
            delegate: self
        )
        let quartzFrame = WindowServer.quartzFrame(for: windowID) ?? selectedWindow.frame
        let overlay = makeOverlayPanel(quartzFrame: quartzFrame)

        stream = captureStream
        panel = overlay.panel
        captureView = overlay.captureView
        targetWindowID = windowID
        acceptsFrames = true

        do {
            try captureStream.addStreamOutput(
                self,
                type: .screen,
                sampleHandlerQueue: .main
            )
            try await captureStream.startCapture()
        } catch {
            acceptsFrames = false
            try? await captureStream.stopCapture()
            try? captureStream.removeStreamOutput(self, type: .screen)
            clearCapturedState(notify: false)
            throw error
        }

        isPinned = true
        startGeometryTracking()
        overlay.panel.orderFrontRegardless()
        onPinnedStateChange?(true)
    }

    func stop() async {
        guard isPinned || stream != nil else { return }
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }

        acceptsFrames = false
        geometryTimer?.invalidate()
        geometryTimer = nil
        let pendingResize = resizeTask
        pendingResize?.cancel()
        await pendingResize?.value
        resizeTask = nil

        if let stream {
            try? await stream.stopCapture()
            try? stream.removeStreamOutput(self, type: .screen)
        }

        clearCapturedState(notify: true)
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen, acceptsFrames else { return }
        captureView?.enqueue(sampleBuffer)
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, self.acceptsFrames else { return }
            await self.stopAfterStreamFailure(message)
        }
    }

    private func makeConfiguration(pointSize: CGSize, pointScale: CGFloat) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        captureScale = pointScale
        configuration.width = max(2, Int(ceil(pointSize.width * pointScale)))
        configuration.height = max(2, Int(ceil(pointSize.height * pointScale)))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.ignoreShadowsSingleWindow = true
        return configuration
    }

    private func makeOverlayPanel(quartzFrame: CGRect) -> (panel: NSPanel, captureView: CaptureView) {
        let frame = WindowGeometry.appKitFrame(
            fromQuartzFrame: quartzFrame,
            mainScreenHeight: primaryScreenHeight
        )
        let captureView = CaptureView(frame: NSRect(origin: .zero, size: frame.size))
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = captureView
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        return (panel, captureView)
    }

    private func startGeometryTracking() {
        let timer = Timer(
            timeInterval: 0.15,
            target: self,
            selector: #selector(refreshWindowGeometry),
            userInfo: nil,
            repeats: true
        )
        geometryTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    @objc private func refreshWindowGeometry() {
        guard let targetWindowID else { return }
        guard let quartzFrame = WindowServer.quartzFrame(for: targetWindowID) else {
            Task { @MainActor [weak self] in
                await self?.stop()
            }
            return
        }

        let appKitFrame = WindowGeometry.appKitFrame(
            fromQuartzFrame: quartzFrame,
            mainScreenHeight: primaryScreenHeight
        )
        guard panel?.frame != appKitFrame else { return }

        let sizeChanged = panel?.frame.size != appKitFrame.size
        panel?.setFrame(appKitFrame, display: true)
        if sizeChanged {
            scheduleCaptureResize(to: quartzFrame.size)
        }
    }

    private func scheduleCaptureResize(to pointSize: CGSize) {
        guard let stream else { return }
        let configuration = makeConfiguration(
            pointSize: pointSize,
            pointScale: captureScale
        )

        let previousResize = resizeTask
        previousResize?.cancel()
        resizeTask = Task { @MainActor [weak self] in
            await previousResize?.value
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            do {
                try await stream.updateConfiguration(configuration)
            } catch {
                guard !Task.isCancelled else { return }
                self?.onFailure?("调整捕获尺寸失败：\(error.localizedDescription)")
            }
        }
    }

    private func stopAfterStreamFailure(_ message: String) async {
        acceptsFrames = false
        isTransitioning = false
        await stop()
        onFailure?("捕获已停止：\(message)")
    }

    private func clearCapturedState(notify: Bool) {
        captureView?.clear()
        panel?.orderOut(nil)
        panel?.close()

        stream = nil
        captureView = nil
        panel = nil
        targetWindowID = nil
        isPinned = false
        if notify {
            onPinnedStateChange?(false)
        }
    }

    private var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }
}
