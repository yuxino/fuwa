import AppKit
import AVFoundation
import CoreMedia
import ScreenCaptureKit

@MainActor
final class CaptureView: NSView {
    private let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        guard let layer else { return }
        layer.backgroundColor = NSColor.clear.cgColor
        layer.masksToBounds = true

        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = NSColor.clear.cgColor
        layer.addSublayer(displayLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        displayLayer.frame = bounds
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        guard sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }

        let attachments = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[SCStreamFrameInfo: Any]]
        let rawStatus = attachments?.first?[.status] as? Int
        guard rawStatus.flatMap(SCFrameStatus.init(rawValue:)) == .complete else { return }

        if displayLayer.status == .failed || displayLayer.requiresFlushToResumeDecoding {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    func clear() {
        displayLayer.flushAndRemoveImage()
    }
}
