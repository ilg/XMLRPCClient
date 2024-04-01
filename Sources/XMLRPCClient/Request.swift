// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

struct Request<E: Encodable> {
    let methodName: String
    let params: [E]?
    let coder: XMLRPCCoderProtocol

    init(methodName: String, params: [E]?, coder: XMLRPCCoderProtocol = XMLRPCCoder()) {
        self.methodName = methodName
        self.params = params
        self.coder = coder
    }

    func encoded() throws -> XMLDocument {
        var children: [XMLNode] = [
            XMLElement(name: .methodName, stringValue: methodName),
        ]
        if let params {
            children.append(
                XMLElement(name: .params, children: try params.map { value in
                    XMLElement(name: .param, children: [
                        XMLElement(name: .value, children: [try coder.encode(value)]),
                    ])
                })
            )
        }
        let root = XMLElement(name: .methodCall, children: children)
        let document = XMLDocument(rootElement: root)
        document.version = "1.0"
        return document
    }
}
