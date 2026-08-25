import AppKit
import AVFoundation
import CoreGraphics
import CoreMedia
import CoreVideo
import FuwaCore
import ScreenCaptureKit

enum PinSessionError: LocalizedError {
    case invalidTransition(PinTransitionError)
    case captureStartFailed(String)
    case captureStartInterrupted
    case captureFailed(String)
    case freezeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidTransition(let error):
            "Invalid pin state transition: \(error)"
        case .captureStartFailed(let message):
            "Fuwa could not start capturing this window: \(message)"
        case .captureStartInterrupted:
            "The capture stopped while Fuwa was starting it."
        case .captureFailed(let message):
            "Window capture failed: \(message)"
        case .freezeFailed(let message):
            "Fuwa could not preserve the last frame: \(message)"
        }
    }
}

struct PinSnapshot: Identifiable, Equatable {
    let id: UUID
    let sourceWindowID: CGWindowID
    let applicationName: String
    let bundleIdentifier: String?
    let windowTitle: String
    let state: PinState
    let errorMessage: String?

    var canFreeze: Bool {
        state == .live
    }

    var canResume: Bool {
        state == .frozen(.manual) || state == .frozen(.captureInterrupted)
    }

    var isActivelyCapturing: Bool {
        state == .starting || state == .live
    }
}

@MainActor
final class PinSession {
    let id: UUID

    var onChange: (() -> Void)?
    var onGeometryChanged: (() -> Void)?
    var onFailure: ((Error) -> Void)?
    var onScreenRecordingRevoked: (() -> Void)?

    private(set) var descriptor: WindowDescriptor
    private(set) var coordinateSpace: DisplayCoordinateSpace

    private var machine = PinStateMachine()
    private var applicationName: String
    private var bundleIdentifier: String?
    private var windowTitle: String
    private var errorMessage: String?

    private var panel: NSPanel?
    private var captureView: CaptureView?
    private var currentCycle: CaptureCycle?
    private var nextGeneration: UInt64 = 0
    private var resizeTask: Task<Void, Never>?
    private var teardownTask: Task<Void, Never>?
    private var missingObservationCount = 0
    private var isHandlingMissingSource = false

    init(id: UUID = UUID(), target: ResolvedTarget) {
        self.id = id
        descriptor = target.descriptor
        coordinateSpace = target.coordinateSpace
        applicationName = target.window.owningApplication?.applicationName
            ?? target.descriptor.ownerName
            ?? "App"
        bundleIdentifier = target.window.owningApplication?.bundleIdentifier
            ?? target.descriptor.ownerBundleIdentifier
        windowTitle = Self.displayTitle(
            target.window.title,
            fallback: applicationName
        )
    }

    var state: PinState {
        machine.state
    }

    var sourceWindowID: CGWindowID {
        descriptor.id
    }

    var needsWindowTracking: Bool {
        state == .starting || state == .live
    }

    var overlayWindowID: CGWindowID? {
        guard let windowNumber = panel?.windowNumber, windowNumber > 0 else {
            return nil
        }
        return CGWindowID(windowNumber)
    }

    var snapshot: PinSnapshot {
        PinSnapshot(
            id: id,
            sourceWindowID: sourceWindowID,
            applicationName: applicationName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            state: state,
            errorMessage: errorMessage
        )
    }

    func startInitialCapture(with target: ResolvedTarget) async throws {
        do {
            try transition(.targetResolved)
            createPresentationIfNeeded()
            try await beginCapture(with: target, preservingFrozenImage: false)
        } catch {
            await handleStartFailure(error)
            throw error
        }
    }

    func freeze(reason: PinFreezeReason = .manual) async throws {
        guard state == .live else {
            throw PinSessionError.invalidTransition(
                .invalidTransition(from: state, event: .freeze(reason))
            )
        }
        guard let captureView else {
            throw PinSessionError.freezeFailed("The capture view is unavailable.")
        }

        let image: CGImage
        do {
            image = try captureView.makeFrozenImage()
        } catch {
            throw PinSessionError.freezeFailed(error.localizedDescription)
        }

        captureView.presentFrozen(image)
        // A transient source can close in the small gap between receiving the
        // first frame and the deferred live reveal. A valid frozen frame must
        // always make its presentation visible independently of the old stream.
        panel?.orderFrontRegardless()
        try transition(.freeze(reason))
        errorMessage = reason == .captureInterrupted
            ? "Capture was interrupted. The last complete frame is preserved."
            : nil

        let detachedCycle = detachCurrentCycle()
        notifyChange()
        await Self.stopCaptureCycle(detachedCycle)
    }

    func resume(with target: ResolvedTarget) async throws {
        guard case let .frozen(previousFreezeReason) = state,
              previousFreezeReason != .sourceClosed else {
            throw PinSessionError.invalidTransition(
                .invalidTransition(from: state, event: .resume)
            )
        }

        do {
            try transition(.resume)
            updateTarget(target)
            missingObservationCount = 0
            isHandlingMissingSource = false
            errorMessage = nil
            captureView?.prepareForResumeKeepingFrozenImage()
            notifyChange()
            try await beginCapture(with: target, preservingFrozenImage: true)
        } catch {
            if state == .starting {
                let detachedCycle = detachCurrentCycle()
                try? transition(.resumeFailed(previousFreezeReason))
                await Self.stopCaptureCycle(detachedCycle)
            }
            errorMessage = error.localizedDescription
            notifyChange()
            throw error
        }
    }

    func reconcile(
        descriptor currentDescriptor: WindowDescriptor?,
        coordinateSpace currentCoordinateSpace: DisplayCoordinateSpace
    ) {
        guard needsWindowTracking else { return }

        guard
            let currentDescriptor,
            currentDescriptor.ownerPID == descriptor.ownerPID
        else {
            missingObservationCount += 1
            guard missingObservationCount >= 2, !isHandlingMissingSource else { return }
            isHandlingMissingSource = true
            guard let currentCycle else {
                isHandlingMissingSource = false
                return
            }
            let streamID = currentCycle.streamID
            let generation = currentCycle.generation
            Task { @MainActor [weak self] in
                await self?.handlePotentialSourceUnavailable(
                    streamID: streamID,
                    generation: generation
                )
            }
            return
        }

        missingObservationCount = 0
        let previousFrame = descriptor.bounds
        descriptor = currentDescriptor
        coordinateSpace = currentCoordinateSpace
        updatePanelFrame(to: currentDescriptor.bounds)

        let scaleChanged: Bool
        if let currentCycle {
            let latestScale = CGFloat(currentCycle.filter.pointPixelScale)
            scaleChanged = abs(latestScale - currentCycle.pointScale) > 0.001
        } else {
            scaleChanged = false
        }

        if previousFrame.size != currentDescriptor.bounds.size || scaleChanged {
            scheduleCaptureResize(to: currentDescriptor.bounds.size)
        }
        if previousFrame != currentDescriptor.bounds || scaleChanged {
            onGeometryChanged?()
        }
    }

    func markSourceUnavailable() async {
        isHandlingMissingSource = true
        await handleSourceUnavailable()
    }

    /// Performs the privacy-sensitive half of teardown synchronously: every
    /// panel is hidden, every retained frame is cleared, and all callbacks are
    /// detached before any potentially slow ScreenCaptureKit stop is awaited.
    func prepareForStop() {
        if state == .stopped {
            panel?.orderOut(nil)
            captureView?.clearAllPixels()
            return
        }

        guard teardownTask == nil else { return }

        do {
            try transition(.requestStop)
        } catch {
            // Teardown must remain best-effort even if a future state is added
            // without an explicit stop edge.
            errorMessage = error.localizedDescription
        }

        panel?.orderOut(nil)
        captureView?.clearAllPixels()
        let detachedCycle = detachCurrentCycle()
        panel?.close()
        panel = nil
        captureView = nil
        notifyChange()

        teardownTask = Task { @MainActor [weak self, detachedCycle] in
            await Self.stopCaptureCycle(detachedCycle)
            guard let self else { return }
            if self.state == .stopping {
                try? self.transition(.didStop)
            }
            self.teardownTask = nil
            self.notifyChange()
        }
    }

    func stop() async {
        prepareForStop()
        let activeTeardown = teardownTask
        await activeTeardown?.value
    }

    fileprivate func receive(
        _ sampleBuffer: CMSampleBuffer,
        streamID: ObjectIdentifier,
        generation: UInt64
    ) {
        guard isCurrent(streamID: streamID, generation: generation) else { return }
        guard let receipt = captureView?.consume(sampleBuffer) else { return }

        missingObservationCount = 0
        guard receipt == .firstCompleteFrame, state == .starting else { return }

        do {
            try transition(.firstCompleteFrame)
        } catch {
            errorMessage = error.localizedDescription
            onFailure?(error)
            return
        }

        errorMessage = nil
        notifyChange()
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.isCurrent(streamID: streamID, generation: generation) else {
                return
            }
            self.panel?.orderFrontRegardless()
            await Task.yield()
            guard self.isCurrent(streamID: streamID, generation: generation) else {
                return
            }
            self.captureView?.completeFirstPresentation()
        }
    }

    fileprivate func streamStopped(
        streamID: ObjectIdentifier,
        generation: UInt64,
        message: String
    ) {
        guard isCurrent(streamID: streamID, generation: generation) else { return }
        Task { @MainActor [weak self] in
            await self?.handleUnexpectedStreamEnd(
                streamID: streamID,
                generation: generation,
                message: message
            )
        }
    }

    fileprivate func sourceBecameInactive(
        streamID: ObjectIdentifier,
        generation: UInt64
    ) {
        guard isCurrent(streamID: streamID, generation: generation) else { return }
        guard !isHandlingMissingSource else { return }
        isHandlingMissingSource = true
        Task { @MainActor [weak self] in
            await self?.handleSourceUnavailable(
                streamID: streamID,
                generation: generation
            )
        }
    }

    private func beginCapture(
        with target: ResolvedTarget,
        preservingFrozenImage: Bool
    ) async throws {
        updateTarget(target)
        createPresentationIfNeeded()
        updatePanelFrame(to: target.descriptor.bounds)
        if !preservingFrozenImage {
            captureView?.clearAllPixels()
        }

        let filter = SCContentFilter(desktopIndependentWindow: target.window)
        let pointScale = max(1, CGFloat(filter.pointPixelScale))
        let configuration = makeConfiguration(
            pointSize: Self.capturePointSize(
                filter: filter,
                fallback: target.descriptor.bounds.size
            ),
            pointScale: pointScale
        )

        nextGeneration &+= 1
        if nextGeneration == 0 {
            nextGeneration = 1
        }
        let generation = nextGeneration
        let bridge = StreamCallbackBridge(generation: generation)
        bridge.owner = self
        let stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: bridge
        )
        let cycle = CaptureCycle(
            generation: generation,
            stream: stream,
            bridge: bridge,
            filter: filter,
            pointScale: pointScale
        )
        currentCycle = cycle

        do {
            try stream.addStreamOutput(
                bridge,
                type: .screen,
                sampleHandlerQueue: .main
            )
            try await stream.startCapture()
        } catch {
            guard currentCycle === cycle else {
                // Another operation detached this cycle and exclusively owns
                // its teardown. Never issue a second remove/stop sequence.
                throw PinSessionError.captureStartInterrupted
            }
            let teardown = detachCurrentCycle()
            await Self.stopCaptureCycle(teardown)
            throw PinSessionError.captureStartFailed(error.localizedDescription)
        }

        guard currentCycle === cycle else {
            throw PinSessionError.captureStartInterrupted
        }
    }

    private func handleStartFailure(_ error: Error) async {
        if state == .starting {
            try? transition(.fail(.captureFailed))
        }
        errorMessage = error.localizedDescription
        panel?.orderOut(nil)
        captureView?.clearAllPixels()
        let detachedCycle = detachCurrentCycle()
        await Self.stopCaptureCycle(detachedCycle)
        notifyChange()
    }

    private func handleUnexpectedStreamEnd(
        streamID: ObjectIdentifier,
        generation: UInt64,
        message: String
    ) async {
        guard isCurrent(streamID: streamID, generation: generation) else { return }

        guard CGPreflightScreenCaptureAccess() else {
            // Permission revocation is an app-wide privacy boundary. The
            // coordinator synchronously hides every panel and clears every
            // retained frame, including pins that were already frozen.
            onScreenRecordingRevoked?()
            return
        }

        let currentSource = WindowInventory.currentDescriptor(for: descriptor.id)
        let sourceStillExists = currentSource?.ownerPID == descriptor.ownerPID

        switch state {
        case .live:
            do {
                try await freeze(
                    reason: sourceStillExists ? .captureInterrupted : .sourceClosed
                )
            } catch {
                await failAndHide(
                    reason: .captureFailed,
                    message: message.isEmpty ? error.localizedDescription : message
                )
            }

        case .starting:
            await failAndHide(
                reason: sourceStillExists ? .captureFailed : .sourceClosedBeforeFirstFrame,
                message: message
            )

        default:
            break
        }
    }

    private func handleSourceUnavailable() async {
        defer { isHandlingMissingSource = false }

        switch state {
        case .starting:
            await failAndHide(
                reason: .sourceClosedBeforeFirstFrame,
                message: "The source window closed before the first frame arrived."
            )

        case .live:
            do {
                try await freeze(reason: .sourceClosed)
            } catch {
                await failAndHide(
                    reason: .captureFailed,
                    message: error.localizedDescription
                )
            }

        case .frozen:
            try? transition(.sourceDisappeared)
            notifyChange()

        default:
            break
        }
    }

    private func handleSourceUnavailable(
        streamID: ObjectIdentifier,
        generation: UInt64
    ) async {
        guard isCurrent(streamID: streamID, generation: generation) else {
            isHandlingMissingSource = false
            return
        }
        await handleSourceUnavailable()
    }

    private func handlePotentialSourceUnavailable(
        streamID: ObjectIdentifier,
        generation: UInt64
    ) async {
        guard isCurrent(streamID: streamID, generation: generation),
              missingObservationCount >= 2 else {
            isHandlingMissingSource = false
            return
        }

        if WindowInventory.currentDescriptor(
            for: descriptor.id,
            ownerPID: descriptor.ownerPID
        ) != nil {
            missingObservationCount = 0
            isHandlingMissingSource = false
            return
        }
        await handleSourceUnavailable()
    }

    private func failAndHide(reason: PinFailureReason, message: String) async {
        if state != .failed(reason) {
            try? transition(.fail(reason))
        }
        errorMessage = message
        panel?.orderOut(nil)
        captureView?.clearAllPixels()
        let detachedCycle = detachCurrentCycle()
        await Self.stopCaptureCycle(detachedCycle)
        notifyChange()
        onFailure?(PinSessionError.captureFailed(message))
    }

    private func createPresentationIfNeeded() {
        guard panel == nil else { return }

        let frame = coordinateSpace.appKitFrame(fromQuartzFrame: descriptor.bounds)
        let view = CaptureView(frame: NSRect(origin: .zero, size: frame.size))
        view.autoresizingMask = [.width, .height]
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = view
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.sharingType = .none

        self.panel = panel
        captureView = view
    }

    private func updateTarget(_ target: ResolvedTarget) {
        descriptor = target.descriptor
        coordinateSpace = target.coordinateSpace
        applicationName = target.window.owningApplication?.applicationName
            ?? target.descriptor.ownerName
            ?? applicationName
        bundleIdentifier = target.window.owningApplication?.bundleIdentifier
            ?? target.descriptor.ownerBundleIdentifier
            ?? bundleIdentifier
        windowTitle = Self.displayTitle(target.window.title, fallback: applicationName)
    }

    private func updatePanelFrame(to quartzFrame: CGRect) {
        let appKitFrame = coordinateSpace.appKitFrame(fromQuartzFrame: quartzFrame)
        guard appKitFrame.width > 0, appKitFrame.height > 0 else { return }
        guard panel?.frame != appKitFrame else { return }
        panel?.setFrame(appKitFrame, display: true)
    }

    private func scheduleCaptureResize(to pointSize: CGSize) {
        guard let currentCycle else { return }

        let latestScale = max(1, CGFloat(currentCycle.filter.pointPixelScale))
        let configuration = makeConfiguration(
            pointSize: pointSize,
            pointScale: latestScale
        )
        let generation = currentCycle.generation
        let streamID = currentCycle.streamID
        let stream = currentCycle.stream
        let previousResize = resizeTask
        previousResize?.cancel()

        resizeTask = Task { @MainActor [weak self] in
            await previousResize?.value
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            guard let self, self.isCurrent(streamID: streamID, generation: generation) else {
                return
            }
            do {
                try await stream.updateConfiguration(configuration)
                guard self.isCurrent(streamID: streamID, generation: generation) else {
                    return
                }
                self.currentCycle?.pointScale = latestScale
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                self.notifyChange()
            }
        }
    }

    private func makeConfiguration(
        pointSize: CGSize,
        pointScale: CGFloat
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
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

    private func transition(_ event: PinEvent) throws {
        do {
            _ = try machine.apply(event)
        } catch let error as PinTransitionError {
            throw PinSessionError.invalidTransition(error)
        }
    }

    private func detachCurrentCycle() -> CaptureTeardown? {
        let detachedResizeTask = resizeTask
        detachedResizeTask?.cancel()
        resizeTask = nil
        guard let detachedCycle = currentCycle else { return nil }
        currentCycle = nil
        detachedCycle.bridge.owner = nil
        return CaptureTeardown(
            cycle: detachedCycle,
            resizeTask: detachedResizeTask
        )
    }

    private static func stopCaptureCycle(_ teardown: CaptureTeardown?) async {
        guard let teardown else { return }
        await teardown.resizeTask?.value
        let cycle = teardown.cycle
        try? cycle.stream.removeStreamOutput(cycle.bridge, type: .screen)
        try? await cycle.stream.stopCapture()
    }

    private func isCurrent(streamID: ObjectIdentifier, generation: UInt64) -> Bool {
        guard let currentCycle else { return false }
        return currentCycle.generation == generation && currentCycle.streamID == streamID
    }

    private func notifyChange() {
        onChange?()
    }

    private static func capturePointSize(
        filter: SCContentFilter,
        fallback: CGSize
    ) -> CGSize {
        let contentSize = filter.contentRect.size
        guard contentSize.width > 0, contentSize.height > 0 else { return fallback }
        return contentSize
    }

    private static func displayTitle(_ title: String?, fallback: String) -> String {
        guard let title else { return fallback }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

@MainActor
private final class CaptureTeardown {
    let cycle: CaptureCycle
    let resizeTask: Task<Void, Never>?

    init(cycle: CaptureCycle, resizeTask: Task<Void, Never>?) {
        self.cycle = cycle
        self.resizeTask = resizeTask
    }
}

@MainActor
private final class CaptureCycle {
    let generation: UInt64
    let stream: SCStream
    let streamID: ObjectIdentifier
    let bridge: StreamCallbackBridge
    let filter: SCContentFilter
    var pointScale: CGFloat

    init(
        generation: UInt64,
        stream: SCStream,
        bridge: StreamCallbackBridge,
        filter: SCContentFilter,
        pointScale: CGFloat
    ) {
        self.generation = generation
        self.stream = stream
        streamID = ObjectIdentifier(stream)
        self.bridge = bridge
        self.filter = filter
        self.pointScale = pointScale
    }
}

@MainActor
private final class StreamCallbackBridge: NSObject,
    @preconcurrency SCStreamOutput,
    SCStreamDelegate
{
    nonisolated let generation: UInt64
    weak var owner: PinSession?

    init(generation: UInt64) {
        self.generation = generation
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        guard outputType == .screen else { return }
        owner?.receive(
            sampleBuffer,
            streamID: ObjectIdentifier(stream),
            generation: generation
        )
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        let streamID = ObjectIdentifier(stream)
        let generation = generation
        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            self?.owner?.streamStopped(
                streamID: streamID,
                generation: generation,
                message: message
            )
        }
    }

    @available(macOS 15.2, *)
    nonisolated func streamDidBecomeInactive(_ stream: SCStream) {
        let streamID = ObjectIdentifier(stream)
        let generation = generation
        Task { @MainActor [weak self] in
            self?.owner?.sourceBecameInactive(
                streamID: streamID,
                generation: generation
            )
        }
    }
}
