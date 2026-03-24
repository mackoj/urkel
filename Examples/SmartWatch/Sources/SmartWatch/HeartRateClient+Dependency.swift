import Foundation
import Dependencies

extension HeartRateClient: DependencyKey {
    public static let testValue = Self(
        makeHeartRate: {
                    _ in fatalError("Configure HeartRateClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeHeartRate: {
                    _ in fatalError("Configure HeartRateClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated HeartRateClient dependency.
    public var heartRate: HeartRateClient {
        get { self[HeartRateClient.self] }
        set { self[HeartRateClient.self] = newValue }
    }
}