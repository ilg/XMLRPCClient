// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

extension Data: ResponseParsable {
    func xmlrpcParseResponse<D: Decodable>(coder: XMLRPCCoderProtocol) throws -> D {
        guard let xmlDocument = try? XMLDocument(data: self) else { throw ResponseParsingError.malformedResponse }
        return try xmlDocument.xmlrpcParseResponse(coder: coder)
    }
}
