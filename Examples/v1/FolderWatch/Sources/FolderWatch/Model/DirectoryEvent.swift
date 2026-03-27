import Foundation

// MARK: - Directory Event

/// Event representing a change in a directory.
public struct DirectoryEvent: Sendable, Equatable {
  /// Information about the affected file.
  public let file: FileInfo
  
  /// Type of file system change.
  public let kind: Kind
  
  /// File system event types.
  public enum Kind: Sendable, Equatable {
    case created
    case deleted
    case modified
    case renamed
  }
  
  public init(file: FileInfo, kind: Kind) {
    self.file = file
    self.kind = kind
  }
}
