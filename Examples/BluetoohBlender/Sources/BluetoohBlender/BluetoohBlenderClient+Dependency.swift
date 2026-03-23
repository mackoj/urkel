import CoreBluetooth
import Dependencies

extension BluetoohBlenderClient: DependencyKey {
    public static let testValue = Self(
        makeBlender: {
                    fatalError("Configure BluetoohBlenderClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makeBlender: {
                    fatalError("Configure BluetoohBlenderClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated BluetoohBlenderClient dependency.
    public var bluetoohBlender: BluetoohBlenderClient {
        get { self[BluetoohBlenderClient.self] }
        set { self[BluetoohBlenderClient.self] = newValue }
    }
}