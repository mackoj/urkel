import Foundation
import Dependencies

extension SomeFeature2Client: DependencyKey {
    public static let testValue = Self(
        makeSomeFeature2: {
                    fatalError("Configure SomeFeature2Client.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeSomeFeature2: {
                    fatalError("Configure SomeFeature2Client.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated SomeFeature2Client dependency.
    public var someFeature2: SomeFeature2Client {
        get { self[SomeFeature2Client.self] }
        set { self[SomeFeature2Client.self] = newValue }
    }
}