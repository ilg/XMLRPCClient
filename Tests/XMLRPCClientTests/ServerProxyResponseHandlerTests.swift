// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import XCTest
@testable import XMLRPCClient
import XMLRPCCoder

class ServerProxyResponseHandlerTests: XCTestCase {
    let serverProxy: ServerProxy = .init(session: URLSession.shared, url: URL(string: "http://localhost/")!)

    func testNoData() {
        var handlerCallbackFinished = false
        let response = HTTPURLResponse(url: serverProxy.url, statusCode: 200, httpVersion: nil, headerFields: nil)
        serverProxy.dataTaskResponseHandler(data: nil, response: response, error: nil) { (result: ServerProxy.Result<String>) in
            do {
                _ = try result.get()
                XCTFail()
            } catch ServerProxy.Error.noData {
                XCTAssert(true)
            } catch {
                XCTFail("error: \(error)")
            }
            handlerCallbackFinished = true
        }
        XCTAssert(handlerCallbackFinished)
    }

    func testNoResponse() {
        var handlerCallbackFinished = false
        let err = NSError(domain: "", code: 0, userInfo: nil)
        serverProxy.dataTaskResponseHandler(data: nil, response: nil, error: err) { (result: ServerProxy.Result<String>) in
            result.assertNetworkError { error in
                XCTAssert(err === error)
            }
            handlerCallbackFinished = true
        }
        XCTAssert(handlerCallbackFinished)
    }

    func testResponseNotHTTPResponse() {
        var handlerCallbackFinished = false
        let resp = URLResponse(url: serverProxy.url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        serverProxy.dataTaskResponseHandler(data: nil, response: resp, error: nil) { (result: ServerProxy.Result<String>) in
            result.assertNetworkError { (error: Error?) in
                XCTAssertNil(error)
            }
            handlerCallbackFinished = true
        }
        XCTAssert(handlerCallbackFinished)
    }

    func testResponseNot200() {
        var handlerCallbackFinished = false
        let resp = HTTPURLResponse(url: serverProxy.url, statusCode: 400, httpVersion: nil, headerFields: nil)
        serverProxy.dataTaskResponseHandler(data: nil, response: resp, error: nil) { (result: ServerProxy.Result<String>) in
            result.assertHTTPError { response in
                XCTAssert(resp === response)
            }
            handlerCallbackFinished = true
        }
        XCTAssert(handlerCallbackFinished)
    }

    func testMalformedResponse() {
        var handlerCallbackFinished = false
        let data = "".data(using: .utf8) // Not a valid response.
        let resp = HTTPURLResponse(url: serverProxy.url, statusCode: 200, httpVersion: nil, headerFields: nil)
        serverProxy.dataTaskResponseHandler(data: data, response: resp, error: nil) { (result: ServerProxy.Result<String>) in
            do {
                _ = try result.get()
                XCTFail()
            } catch ServerProxy.Error.responseParsing(.malformedResponse) {
                XCTAssert(true)
            } catch {
                XCTFail("error: \(error)")
            }
            handlerCallbackFinished = true
        }
        XCTAssert(handlerCallbackFinished)
    }

    func testDecodeTypeMismatch() {
        var handlerCallbackFinished = false
        let data = """
        <?xml version="1.0"?>
        <methodResponse>
        <params>
        <param>
        <value><string>South Dakota</string></value>
        </param>
        </params>
        </methodResponse>
        """.data(using: .utf8) // A valid response containing only a string.
        let resp = HTTPURLResponse(url: serverProxy.url, statusCode: 200, httpVersion: nil, headerFields: nil)
        // Try to parse as Int32
        serverProxy.dataTaskResponseHandler(data: data, response: resp, error: nil) { (result: ServerProxy.Result<Int32>) in
            do {
                _ = try result.get()
                XCTFail()
            } catch let ServerProxy.Error.responseParsing(.decodingError(error)) {
                switch error {
                case let .typeMismatch(type, context):
                    XCTAssert(type == Int32.self)
                    XCTAssert(context.codingPath.isEmpty)
                default:
                    XCTFail("error: \(error)")
                }
            } catch {
                XCTFail("error: \(error)")
            }
            handlerCallbackFinished = true
        }
        XCTAssert(handlerCallbackFinished)
    }

    func testBadCoder() {
        struct BadCoder: XMLRPCCoderProtocol {
            func encode(_: some Encodable) throws -> XMLElement {
                XCTFail()
                fatalError()
            }

            func decode<D: Decodable>(toType _: D.Type, from _: XMLElement) throws -> D {
                throw NSError(domain: "", code: 0, userInfo: nil)
            }
        }
        let serverProxy = ServerProxy(session: URLSession.shared, url: URL(string: "http://localhost/")!, coder: BadCoder())
        var handlerCallbackFinished = false
        let data = try! XMLDocument(xmlString: """
        <?xml version="1.0"?>
        <methodResponse>
        <params>
        <param>
        <value><string>South Dakota</string></value>
        </param>
        </params>
        </methodResponse>
        """).xmlData
        let resp = HTTPURLResponse(url: serverProxy.url, statusCode: 200, httpVersion: nil, headerFields: nil)
        serverProxy.dataTaskResponseHandler(data: data, response: resp, error: nil) { (result: ServerProxy.Result<String>) in
            do {
                _ = try result.get()
                XCTFail()
            } catch ServerProxy.Error.internalInconsistency {
                XCTAssert(true)
            } catch {
                XCTFail("error: \(error)")
            }
            handlerCallbackFinished = true
        }
        XCTAssert(handlerCallbackFinished)
    }
}
