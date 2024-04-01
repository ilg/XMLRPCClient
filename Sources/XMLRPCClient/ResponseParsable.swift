// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

protocol ResponseParsable {
    func xmlrpcParseResponse<D: Decodable>() throws -> D
    func xmlrpcParseResponse<D: Decodable>(coder: XMLRPCCoderProtocol) throws -> D
}

extension ResponseParsable {
    func xmlrpcParseResponse<D: Decodable>() throws -> D {
        try xmlrpcParseResponse(coder: XMLRPCCoder())
    }
}
