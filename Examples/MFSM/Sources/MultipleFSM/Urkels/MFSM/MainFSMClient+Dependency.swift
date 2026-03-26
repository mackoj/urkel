import Foundation
import Dependencies

extension MainFSMClient: DependencyKey {
    public static let testValue = Self(
        makeMainFSM: {
                    fatalError("Configure MainFSMClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeMainFSM: {
                    fatalError("Configure MainFSMClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated MainFSMClient dependency.
    public var mainFSM: MainFSMClient {
        get { self[MainFSMClient.self] }
        set { self[MainFSMClient.self] = newValue }
    }
}