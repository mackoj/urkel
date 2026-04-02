// Internal error type for primitive parser failures.
// The file-level parser converts these to UrkelParseError with line/column info.

import Foundation

enum ParseFailure: Error {
    case expected(String)
    case message(String)
}
