import Darwin
import Foundation

/// A process-lifetime lock. The file must remain in place: unlinking a held
/// lock would allow another process to lock a different inode at the same path.
public final class SingleInstanceLock {
    private let descriptor: Int32

    public init?(url: URL) throws {
        let descriptor = open(url.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let error = errno
            close(descriptor)
            if error == EWOULDBLOCK { return nil }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(error))
        }
        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
    }
}
