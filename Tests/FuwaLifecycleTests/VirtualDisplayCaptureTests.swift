import AppKit
import CoreGraphics
import ImageIO
import Testing
import UniformTypeIdentifiers
import Vision
@testable import Fuwa

/// Opt-in local integration probe. Requires the disposable FuwaDisplayQA fixture.
/// Never requests permission and never selects user windows.
@Suite(.serialized)
@MainActor
struct VirtualDisplayCaptureTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["FUWA_VIRTUAL_CAPTURE_QA"] == "1"))
    func captureFixtureAcrossDisplays() async throws {
        #expect(CGPreflightScreenCaptureAccess(), "Existing screen recording permission is required")
        guard CGPreflightScreenCaptureAccess() else { return }
        _ = NSApplication.shared
        let inventory = try WindowInventory.capture()
        let descriptor = try #require(inventory.orderedWindows.first {
            $0.ownerBundleIdentifier == "local.fuwa.displayqa" && $0.bounds.width > 500
        })
        let resolver = TargetResolver()
        let target = try await resolver.resolveExact(matching: descriptor)
        let session = PinSession(target: target)
        let directory = URL(fileURLWithPath: "/private/tmp/fuwa-capture-qa", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let log = directory.appendingPathComponent("frames.tsv")
        try Data("step\tx\ty\twidth\theight\tstate\ttext\n".utf8).write(to: log)
        let handle = try FileHandle(forWritingTo: log)
        defer { try? handle.close() }
        try handle.seekToEnd()
        do {
            try await session.startInitialCapture(with: target)
            let view = try #require(Mirror(reflecting: session).descendant("captureView") as? CaptureView)
            var observedTexts = Set<String>()
            var frozenPixels: Data?
            for step in 0..<40 {
                try await Task.sleep(for: .seconds(2))
                let current = try WindowInventory.capture()
                session.reconcile(descriptor: current.descriptor(for: descriptor.id), coordinateSpace: current.coordinateSpace)
                if step == 25 { try await session.freeze() }
                if step == 30 { try await session.resume(with: resolver.resolveExact(matching: descriptor)) }
                let image: CGImage
                if step >= 25 && step < 30 {
                    let frozenLayer = try #require(Mirror(reflecting: view).descendant("frozenLayer") as? CALayer)
                    let contents = try #require(frozenLayer.contents)
                    try #require(CFGetTypeID(contents as CFTypeRef) == CGImage.typeID)
                    image = contents as! CGImage
                    let pixels = try #require(image.dataProvider?.data as Data?)
                    if let frozenPixels { #expect(pixels == frozenPixels) } else { frozenPixels = pixels }
                } else {
                    image = try view.makeFrozenImage()
                }
                let bitmap = NSBitmapImageRep(cgImage: image)
                let interior = [NSPoint(x: image.width / 4, y: image.height / 4),
                                NSPoint(x: image.width * 3 / 4, y: image.height * 3 / 4)]
                for point in interior {
                    let color = try #require(bitmap.colorAt(x: Int(point.x), y: Int(point.y)))
                    #expect(color.alphaComponent > 0.99, "The fixture must fill the capture canvas after a scale change")
                }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                try VNImageRequestHandler(cgImage: image).perform([request])
                let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " | ")
                if step < 25 || step >= 30 { observedTexts.insert(text) }
                #expect(text.contains("counter"), "The captured fixture text must be present, not a blank frame")
                let line = "\(step)\t\(session.descriptor.bounds.minX)\t\(session.descriptor.bounds.minY)\t\(image.width)\t\(image.height)\t\(session.state)\t\(text)\n"
                try handle.write(contentsOf: Data(line.utf8))
                let url = directory.appendingPathComponent("frame-\(step).png")
                let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
                CGImageDestinationAddImage(destination, image, nil)
                #expect(CGImageDestinationFinalize(destination))
            }
            #expect(observedTexts.count > 10, "Live capture must contain changing counter values")
            await session.stop()
        } catch {
            await session.stop()
            throw error
        }
    }
}
