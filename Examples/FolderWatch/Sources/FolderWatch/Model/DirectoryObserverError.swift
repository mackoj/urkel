import Foundation

// MARK: - Errors

/// Errors that can occur during directory observation.
public enum DirectoryObserverError: Error, Sendable {
  case unableToOpenDirectory(String)
  case observationFailed(String)
  case cancelled
}
