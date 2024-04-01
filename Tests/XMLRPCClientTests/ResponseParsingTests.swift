// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import XCTest
@testable import XMLRPCClient
import XMLRPCCoder

class ResponseParsingTests: XCTestCase {
    let coder: XMLRPCCoderProtocol = XMLRPCCoder()

    func testParseSpecFaultExample() {
        do {
            _ = try """
            <?xml version="1.0"?>
            <methodResponse>
               <fault>
                  <value>
                     <struct>
                        <member>
                           <name>faultCode</name>
                           <value><int>4</int></value>
                           </member>
                        <member>
                           <name>faultString</name>
                           <value><string>Too many parameters.</string></value>
                           </member>
                        </struct>
                     </value>
                  </fault>
               </methodResponse>
            """.xmlrpcParseResponse(coder: coder) as String
            XCTFail("Parsing didn't catch fault response")
        } catch ResponseParsingError.malformedResponse {
            XCTFail("Unexpected malformed response")
        } catch let ResponseParsingError.fault(code, string) {
            XCTAssertEqual(code, 4)
            XCTAssertEqual(string, "Too many parameters.")
        } catch {
            XCTFail("Unexpected error.")
        }
    }

    func testParseSpecSuccessExample() {
        do {
            let response: String = try """
            <?xml version="1.0"?>
            <methodResponse>
            <params>
            <param>
            <value><string>South Dakota</string></value>
            </param>
            </params>
            </methodResponse>
            """.xmlrpcParseResponse(coder: coder)
            XCTAssertEqual(response, "South Dakota")
        } catch ResponseParsingError.malformedResponse {
            XCTFail("Unexpected malformed response")
        } catch ResponseParsingError.fault {
            XCTFail("Unexpected fault response")
        } catch {
            XCTFail("Unexpected error.")
        }
    }

    func testParseSpecSuccessExampleWithDefaultCoder() {
        do {
            let response: String = try """
            <?xml version="1.0"?>
            <methodResponse>
            <params>
            <param>
            <value><string>South Dakota</string></value>
            </param>
            </params>
            </methodResponse>
            """.xmlrpcParseResponse()
            XCTAssertEqual(response, "South Dakota")
        } catch ResponseParsingError.malformedResponse {
            XCTFail("Unexpected malformed response")
        } catch ResponseParsingError.fault {
            XCTFail("Unexpected fault response")
        } catch {
            XCTFail("Unexpected error.")
        }
    }

    func testParseLiveJournalConsoleCommandExample() {
        struct ConsoleCommandResponse: Codable {
            let results: [ConsoleCommandResult]
        }
        struct ConsoleCommandResult: Codable {
            let success: Int32
            let output: [[String]]
        }
        do {
            let response: ConsoleCommandResponse = try """
            <?xml version="1.0"?>
            <methodResponse>
            <params>
            <param>
            <value><struct>
            <member><name>results</name>

            <value><array>
            <data>
            <value><struct>
            <member><name>success</name>
            <value><int>1</int></value>

            </member>
            <member><name>output</name>
            <value><array>
            <data>
            <value><array>
            <data>

            <value><string></string></value>
            <value><string>print ...</string></value>
            </data>
            </array></value>
            <value><array>

            <data>
            <value><string></string></value>
            <value><string>  This is a debugging function.  Given an arbitrary number of</string></value>
            </data>
            </array></value>

            <value><array>
            <data>
            <value><string></string></value>
            <value><string>  meaningless arguments, it'll print each one back to you.  If an</string></value>

            </data>
            </array></value>
            <value><array>
            <data>
            <value><string></string></value>
            <value><string>  argument begins with a bang (!) then it'll be printed to the error</string></value>

            </data>
            </array></value>
            <value><array>
            <data>
            <value><string></string></value>
            <value><string>  stream instead.</string></value>

            </data>
            </array></value>
            </data>
            </array></value>
            </member>
            </struct></value>
            </data>

            </array></value>
            </member>
            </struct></value>
            </param>
            </params>
            </methodResponse>
            """.xmlrpcParseResponse(coder: coder)
            XCTAssertEqual(response.results.count, 1)

            guard
                let result = response.results.first
            else { XCTFail(); return }
            XCTAssertEqual(result.success, 1)

            XCTAssertEqual(result.output.count, 5)
            for line in result.output {
                guard
                    line.count == 2
                else { XCTFail(); continue }
                XCTAssertEqual(line.first, "")
            }
            XCTAssertEqual(result.output[0].last, "print ...")
            XCTAssertEqual(result.output[1].last, "  This is a debugging function.  Given an arbitrary number of")
            XCTAssertEqual(result.output[2].last, "  meaningless arguments, it'll print each one back to you.  If an")
            XCTAssertEqual(result.output[3].last, "  argument begins with a bang (!) then it'll be printed to the error")
            XCTAssertEqual(result.output[4].last, "  stream instead.")
        } catch ResponseParsingError.malformedResponse {
            XCTFail("Unexpected malformed response")
        } catch ResponseParsingError.fault {
            XCTFail("Unexpected fault response")
        } catch {
            XCTFail("Unexpected error.")
        }
    }

    func testWithAllTypes() {
        struct Test: Codable {
            let preEpochDate: Date
            let someData: Data
            let aString: String
            let ints: [Int32]
            let doubles: [Double]
            let bools: [Bool]
        }
        let test = Test(
            preEpochDate: Date(timeIntervalSince1970: -1000),
            someData: "unicode ïåeáî®©†µπœ∑".data(using: .utf8)!,
            aString: "a string",
            ints: [-1000, 37, 0, 9_999_999],
            doubles: [
                -1000,
                37,
                0,
                9_999_999,
                Double.pi,
                Double.leastNormalMagnitude,
                Double.leastNonzeroMagnitude,
                2.718281828,
                0.999999999,
                -0.3,
            ],
            bools: [true, false, false, true]
        )
        do {
            let response: Test = try """
            <?xml version="1.0"?>
            <methodResponse>
            <params>
            <param>
            <value>
            \(try! coder.encode(test).xmlString)
            </value>
            </param>
            </params>
            </methodResponse>
            """.xmlrpcParseResponse(coder: coder)
            XCTAssertEqual(test.preEpochDate, response.preEpochDate)
            XCTAssertEqual(test.someData, response.someData)
            XCTAssertEqual(test.aString, response.aString)
            XCTAssertEqual(test.ints, response.ints)
            for (d1, d2) in zip(test.doubles, response.doubles) {
                XCTAssertEqual(d1, d2, accuracy: 0.0000000001)
            }
            XCTAssertEqual(test.bools, response.bools)
        } catch ResponseParsingError.malformedResponse {
            XCTFail("Unexpected malformed response")
        } catch ResponseParsingError.fault {
            XCTFail("Unexpected fault response")
        } catch {
            XCTFail("Unexpected error.")
        }
    }
}
