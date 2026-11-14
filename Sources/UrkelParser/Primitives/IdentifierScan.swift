// EBNF: Identifier ::= (Letter | "_") {Letter | Digit | "_"}

extension Substring {
    /// The index of the first character that cannot continue an identifier: anything but a letter, a digit, `_` and
    /// `extra` (`.` in a dotted state reference, `*` in a reactive source).
    ///
    /// The same index as `firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != extra })`. ASCII,
    /// by far the common case, is scanned as bytes: grapheme breaking and Unicode property lookups on every
    /// `Character` were the parser's largest cost. An ASCII character is always its own `Character` here (the
    /// parser normalises `\r\n` first), so stopping before one stops on a `Character` boundary. A non-ASCII byte
    /// before the end of the identifier sends the whole scan down the `Character` path.
    func identifierEnd(allowing extra: Character? = nil) -> Index {
        let extraByte = extra?.asciiValue
        var index = utf8.startIndex
        while index < utf8.endIndex {
            let byte = utf8[index]
            guard byte < 0x80 else {
                return firstIndex(where: { !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != extra }) ?? endIndex
            }
            let continues =
                (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
                || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
                || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
                || byte == UInt8(ascii: "_") || byte == extraByte
            guard continues else { return index }
            index = utf8.index(after: index)
        }
        return endIndex
    }
}

extension String {
    /// The parts of a dotted state reference, as `components(separatedBy: ".")` returns them (empty parts kept)
    /// without bridging to Foundation.
    var dottedComponents: [String] {
        split(separator: Character("."), omittingEmptySubsequences: false).map(String.init)
    }
}
