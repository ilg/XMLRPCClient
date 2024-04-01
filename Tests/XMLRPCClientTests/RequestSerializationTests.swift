// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import XCTest
import XMLAssertions
@testable import XMLRPCClient

class RequestSerializationTests: XCTestCase {
    func testSpecExample() {
        AssertXMLEqualToString(
            xml: try! Request(
                methodName: "examples.getStateName",
                params: [Int32(41)]
            ).encoded(),
            string: """
            <?xml version="1.0"?>
            <methodCall>
               <methodName>examples.getStateName</methodName>
               <params>
                  <param>
                     <value><i4>41</i4></value>
                     </param>
                  </params>
               </methodCall>
            """
        )
    }
}
