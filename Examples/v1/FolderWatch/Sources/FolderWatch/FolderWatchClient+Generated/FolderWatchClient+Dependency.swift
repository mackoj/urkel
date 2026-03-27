import Foundation
import Dependencies

extension FolderWatchClient: DependencyKey {
    public static let testValue = Self(
        makeObserver: {
                    _, _ in fatalError("Configure FolderWatchClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeObserver: {
                    _, _ in fatalError("Configure FolderWatchClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated FolderWatchClient dependency.
    public var folderWatch: FolderWatchClient {
        get { self[FolderWatchClient.self] }
        set { self[FolderWatchClient.self] = newValue }
    }
}