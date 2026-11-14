import Foundation

/// What separates the words of a DSL identifier: anything but a letter or digit.
private let identifierSeparators = CharacterSet.alphanumerics.inverted

/// Where a parameter's type expression stops being its base type name: `Result<A, B>` → `Result`.
private let typeExprSeparators = CharacterSet(charactersIn: ":<>[]?,")

private func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
    (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte) || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
        || (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
}

/// Converts a raw DSL identifier to PascalCase.
///
///     "folderWatch"  → "FolderWatch"
///     "BLE"          → "BLE"
///     "my-machine"   → "MyMachine"
public func typeName(from raw: String) -> String {
    // Fast path: an ASCII identifier has no separators, so it is one part whose first letter is uppercased. The
    // emitter names every type and property through here, so the general path below dominated emission.
    if let first = raw.utf8.first, raw.utf8.allSatisfy(isASCIIAlphanumeric) {
        guard first >= UInt8(ascii: "a"), first <= UInt8(ascii: "z") else { return raw }
        var bytes = Array(raw.utf8)
        bytes[0] = first - UInt8(ascii: "a") + UInt8(ascii: "A")
        return String(decoding: bytes, as: UTF8.self)
    }
    let parts = raw.components(separatedBy: identifierSeparators).filter { !$0.isEmpty }
    guard !parts.isEmpty else { return raw }
    return parts.map { part in
        let head = part.prefix(1).uppercased()
        let tail = part.dropFirst()
        return head + tail
    }.joined()
}

/// Converts a PascalCase string to lowerCamelCase.
///
///     "FolderWatch"  → "folderWatch"
///     "BLE"          → "bLE"
public func variableName(from pascal: String) -> String {
    // Fast path for ASCII, as in `typeName(from:)`.
    if let first = pascal.utf8.first, pascal.utf8.allSatisfy({ $0 < 0x80 }) {
        guard first >= UInt8(ascii: "A"), first <= UInt8(ascii: "Z") else { return pascal }
        var bytes = Array(pascal.utf8)
        bytes[0] = first - UInt8(ascii: "A") + UInt8(ascii: "a")
        return String(decoding: bytes, as: UTF8.self)
    }
    guard let first = pascal.first else { return pascal }
    return String(first).lowercased() + pascal.dropFirst()
}

/// Derives the storage property name for a transition closure.
///
/// Unique per (event, paramTypes) signature to avoid collisions when the
/// same event appears with different parameter shapes.
///
///     event: "connect", params: []         → "_connect"
///     event: "connect", params: [Error]    → "_connectError"
public func closurePropertyName(for event: String, params: [Parameter]) -> String {
    let suffix = params.map { typeName(from: $0.typeExpr.components(separatedBy: typeExprSeparators).first ?? $0.typeExpr) }.joined()
    return "_\(variableName(from: typeName(from: event)))\(suffix)"
}

/// Derives the storage property name for a guard predicate closure.
///
///     "hasPaymentMethod" → "_hasPaymentMethod"
public func guardPropertyName(for name: String) -> String {
    "_\(variableName(from: typeName(from: name)))"
}

/// Derives the storage property name for an action closure.
///
///     "showSpinner" → "_showSpinner"
public func actionPropertyName(for name: String) -> String {
    "_\(variableName(from: typeName(from: name)))"
}

/// The phase namespace type name for a machine.
///
///     "FolderWatch" → "FolderWatchPhase"
public func phaseNamespaceName(for machineName: String) -> String {
    "\(typeName(from: machineName))Phase"
}

/// The machine struct type name.
///
///     "FolderWatch" → "FolderWatchMachine"
public func machineTypeName(for machineName: String) -> String {
    "\(typeName(from: machineName))Machine"
}

/// The combined state enum type name.
///
///     "FolderWatch" → "FolderWatchState"
public func stateEnumTypeName(for machineName: String) -> String {
    "\(typeName(from: machineName))State"
}

/// The client struct type name.
///
///     "FolderWatch" → "FolderWatchClient"
public func clientTypeName(for machineName: String) -> String {
    "\(typeName(from: machineName))Client"
}

/// The runtime builder struct type name.
///
///     "FolderWatch" → "FolderWatchClientRuntime"
public func runtimeTypeName(for machineName: String) -> String {
    "\(typeName(from: machineName))ClientRuntime"
}

/// The `DependencyValues` accessor property name.
///
///     "FolderWatch" → "folderWatch"
public func dependencyKeyName(for machineName: String) -> String {
    variableName(from: typeName(from: machineName))
}

/// The fully-qualified phase type for a state name within a machine.
///
///     machineName: "FolderWatch", stateName: "Running"
///     → "FolderWatchPhase.Running"
public func phaseType(machineName: String, stateName: String) -> String {
    "\(phaseNamespaceName(for: machineName)).\(typeName(from: stateName))"
}

/// The machine type specialised to a given phase.
///
///     machineName: "FolderWatch", stateName: "Running"
///     → "FolderWatchMachine<FolderWatchPhase.Running>"
public func specialisedMachineType(machineName: String, stateName: String) -> String {
    "\(machineTypeName(for: machineName))<\(phaseType(machineName: machineName, stateName: stateName))>"
}

/// The enum case name for a state in the combined state enum (lowerCamelCase).
///
///     "Running" → "running"
///     "NoPaymentMethod" → "noPaymentMethod"
public func stateCaseName(for stateName: String) -> String {
    variableName(from: typeName(from: stateName))
}
