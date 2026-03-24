import Foundation
import Dependencies

extension WatchAudioClient: DependencyKey {
    public static let testValue = Self(
        makePlayer: {
                    fatalError("Configure WatchAudioClient.testValue in tests.")
                }
    )

    public static let previewValue = Self(
        makePlayer: {
                    fatalError("Configure WatchAudioClient.previewValue in previews.")
                }
    )

    /// The live production implementation.
    /// Add `public static func makeLive() -> Self` in a `+Live` extension to implement it.
    public static var liveValue: Self { .makeLive() }
}

extension DependencyValues {
    /// Accessor for the generated WatchAudioClient dependency.
    public var watchAudio: WatchAudioClient {
        get { self[WatchAudioClient.self] }
        set { self[WatchAudioClient.self] = newValue }
    }
}