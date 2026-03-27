import Foundation

// MARK: - File Info

/// File information with unique identifier.
public struct FileInfo: Equatable, Sendable, Identifiable {
  public var id: UInt64 { inodeID }
  
  /// File system location.
  public let url: URL
  
  /// File name (last path component).
  public var name: String { url.lastPathComponent }
  
  /// Unique inode identifier.
  public let inodeID: UInt64
  
  /// Creates file info from a URL.
  ///
  /// - Parameter url: File system location
  public init(url: URL) {
#if canImport(Darwin)
    if #available(macOS 13.3, *) {
      let resource = try? url.resourceValues(forKeys: [.fileIdentifierKey])
      self.inodeID = (resource?.fileIdentifier as? NSNumber)?.uint64Value ?? 0
    } else {
      self.inodeID = 0
    }
#else
    self.inodeID = 0
#endif
    self.url = url
  }
}
