// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

private struct Fault: Codable {
    let faultCode: Int32
    let faultString: String
}

extension XMLDocument: ResponseParsable {
    func xmlrpcParseResponse<D>(coder: XMLRPCCoderProtocol = XMLRPCCoder()) throws -> D where D: Decodable {
        guard
            let root = rootElement(),
            root.name == .methodResponse,
            let rootChild = root.singleChild
        else { throw ResponseParsingError.malformedResponse }

        if rootChild.name == .fault {
            guard
                let valueNode = rootChild.singleChild(named: .value),
                let faultNode = valueNode.singleChild as? XMLElement
            else { throw ResponseParsingError.malformedResponse }
            let fault = try coder.decode(toType: Fault.self, from: faultNode)
            throw ResponseParsingError.fault(code: fault.faultCode, string: fault.faultString)
        }

        guard
            rootChild.name == .params,
            let param = rootChild.singleChild(named: .param),
            let valueContainer = param.singleChild(named: .value),
            let value = valueContainer.singleChild as? XMLElement
        else { throw ResponseParsingError.malformedResponse }

        return try coder.decode(toType: D.self, from: value)
    }
}
