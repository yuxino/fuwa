import Foundation

public struct PixelDimensions: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var pixelCount: Int {
        let (count, overflowed) = width.multipliedReportingOverflow(by: height)
        return overflowed ? .max : count
    }
}

public enum FrozenFrameSizing {
    public static func fittedDimensions(
        sourceWidth: Int,
        sourceHeight: Int,
        maxPixels: Int = 4_000_000
    ) -> PixelDimensions? {
        guard sourceWidth > 0, sourceHeight > 0, maxPixels > 0 else { return nil }

        let sourcePixels = Double(sourceWidth) * Double(sourceHeight)
        guard sourcePixels > Double(maxPixels) else {
            return PixelDimensions(width: sourceWidth, height: sourceHeight)
        }

        let scale = sqrt(Double(maxPixels) / sourcePixels)
        let scaledWidth = min(maxPixels, max(1, Int(floor(Double(sourceWidth) * scale))))
        let scaledHeight = max(1, Int(floor(Double(sourceHeight) * scale)))

        // Independently flooring both axes normally stays within the budget. The
        // division guard also covers extreme aspect ratios and floating-point
        // rounding at the boundary.
        let budgetedHeight = min(scaledHeight, max(1, maxPixels / scaledWidth))
        return PixelDimensions(width: scaledWidth, height: budgetedHeight)
    }
}
