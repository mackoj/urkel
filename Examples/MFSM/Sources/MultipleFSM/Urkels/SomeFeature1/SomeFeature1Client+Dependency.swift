import Foundation
import Dependencies

extension SomeFeature1Client: DependencyKey {
    public static let testValue = Self(
        makeSomeFeature1: {
                    fatalError("Configure SomeFeature1Client.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeSomeFeature1: {
                    fatalError("Configure SomeFeature1Client.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated SomeFeature1Client dependency.
    public var someFeature1: SomeFeature1Client {
        get { self[SomeFeature1Client.self] }
        set { self[SomeFeature1Client.self] = newValue }
    }
}