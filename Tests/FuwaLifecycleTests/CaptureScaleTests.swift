import AVFoundation
import ScreenCaptureKit
import Testing
@testable import Fuwa

@MainActor
struct CaptureScaleTests {
    @Test func scaleComesFromEachFrameAndRejectsInvalidMetadata() throws {
        var pixelBuffer: CVPixelBuffer?
        #expect(CVPixelBufferCreate(nil, 8, 8, kCVPixelFormatType_32BGRA, nil, &pixelBuffer) == kCVReturnSuccess)
        let pixels = try #require(pixelBuffer)
        var format: CMVideoFormatDescription?
        #expect(CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixels, formatDescriptionOut: &format) == noErr)
        var sample: CMSampleBuffer?
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        #expect(CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixels,
            formatDescription: try #require(format), sampleTiming: &timing, sampleBufferOut: &sample) == noErr)
        let buffer = try #require(sample)
        #expect(CaptureView.sourcePointScale(buffer) == nil)
        let array = try #require(CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true))
        let metadata = unsafeBitCast(CFArrayGetValueAtIndex(array, 0), to: NSMutableDictionary.self)
        for scale in [2.0, 1.0, 2.0, 4.0] {
            metadata[SCStreamFrameInfo.scaleFactor.rawValue] = NSNumber(value: scale)
            #expect(CaptureView.sourcePointScale(buffer) == CGFloat(scale))
        }
        for scale in [0.0, -1.0, 5.0, .nan, .infinity] {
            metadata[SCStreamFrameInfo.scaleFactor.rawValue] = NSNumber(value: scale)
            #expect(CaptureView.sourcePointScale(buffer) == nil)
        }
        metadata[SCStreamFrameInfo.scaleFactor.rawValue] = "invalid"
        #expect(CaptureView.sourcePointScale(buffer) == nil)
    }
}
