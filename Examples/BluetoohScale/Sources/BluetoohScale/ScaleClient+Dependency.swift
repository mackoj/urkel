import Foundation
import Dependencies

extension ScaleClient: DependencyKey {
    public static let testValue = Self(
        makeScale: {
                    _ in fatalError("Configure ScaleClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeScale: {
                    _ in fatalError("Configure ScaleClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated ScaleClient dependency.
    public var scale: ScaleClient {
        get { self[ScaleClient.self] }
        set { self[ScaleClient.self] = newValue }
    }
}