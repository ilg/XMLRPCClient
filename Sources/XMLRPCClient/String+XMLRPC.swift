// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

extension String: ResponseParsable {
    func xmlrpcParseResponse<D>(coder: XMLRPCCoderProtocol) throws -> D where D: Decodable {
        guard let xmlDocument = try? XMLDocument(xmlString: self) else { throw ResponseParsingError.malformedResponse }
        return try xmlDocument.xmlrpcParseResponse(coder: coder)
    }
}
