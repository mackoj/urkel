import Foundation
import Dependencies

extension BLEClient: DependencyKey {
    public static let testValue = Self(
        makeWatchBLE: {
                    fatalError("Configure BLEClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeWatchBLE: {
                    fatalError("Configure BLEClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated BLEClient dependency.
    public var bLE: BLEClient {
        get { self[BLEClient.self] }
        set { self[BLEClient.self] = newValue }
    }
}