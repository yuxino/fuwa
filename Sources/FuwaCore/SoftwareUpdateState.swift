public enum SoftwareUpdatePhase: String, Equatable, Sendable {
    case idle
    case checking
    case current
    case available
    case downloading
    case extracting
    case ready
    case installing
    case cancelled
    case failed
}

public struct SoftwareUpdateState: Equatable, Sendable {
    public var phase: SoftwareUpdatePhase
    public var currentVersion: String
    public var availableVersion: String?
    public var releaseNotes: String?
    public var expectedBytes: UInt64?
    public var receivedBytes: UInt64
    public var extractionProgress: Double?
    public var errorMessage: String?

    public init(
        phase: SoftwareUpdatePhase,
        currentVersion: String,
        availableVersion: String? = nil,
        releaseNotes: String? = nil,
        expectedBytes: UInt64? = nil,
        receivedBytes: UInt64 = 0,
        extractionProgress: Double? = nil,
        errorMessage: String? = nil
    ) {
        self.phase = phase
        self.currentVersion = currentVersion
        self.availableVersion = availableVersion
        self.releaseNotes = releaseNotes
        self.expectedBytes = expectedBytes
        self.receivedBytes = receivedBytes
        self.extractionProgress = extractionProgress
        self.errorMessage = errorMessage
    }

    public static func idle(currentVersion: String) -> Self {
        Self(phase: .idle, currentVersion: currentVersion)
    }

    public var downloadProgress: Double? {
        guard let expectedBytes, expectedBytes > 0 else { return nil }
        return min(1, Double(receivedBytes) / Double(expectedBytes))
    }

    public var normalizedExtractionProgress: Double? {
        extractionProgress.map { min(1, max(0, $0)) }
    }

    public var isBusy: Bool {
        switch phase {
        case .checking, .downloading, .extracting, .installing:
            true
        case .idle, .current, .available, .ready, .cancelled, .failed:
            false
        }
    }

    public var canCancel: Bool {
        phase == .checking || phase == .downloading
    }

    public var canRetry: Bool {
        phase == .cancelled || phase == .failed
    }
}
