// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation

/// Possible errors when parsing the response from an XML-RPC server.
public enum ResponseParsingError: Error {
    case malformedResponse
    case decodingError(DecodingError)
    case fault(code: Int32, string: String)
}
