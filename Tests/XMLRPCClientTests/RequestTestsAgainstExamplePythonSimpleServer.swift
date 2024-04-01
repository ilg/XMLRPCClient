// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import ResultAssertions
import XCTest
import XMLRPCClient

private let timeout: TimeInterval = 1

class RequestTestsAgainstExamplePythonSimpleServer: XCTestCase {
    static let simpleServer: Process = .init()
    static let stdout: Pipe = .init()
    static let stderr: Pipe = .init()

    override class func setUp() {
        super.setUp()
        guard let serverScriptPath = Bundle.module.path(forResource: "xmlrpc_server", ofType: "py") else {
            fatalError()
        }
        simpleServer.launchPath = serverScriptPath
        simpleServer.standardError = stderr
        simpleServer.standardOutput = stdout
        simpleServer.launch()
        // Give a little breathing room to let the test server start up.
        Thread.sleep(until: Date().addingTimeInterval(0.1))
    }

    override class func tearDown() {
        simpleServer.terminate()
        print("stdout:")
        print(String(data: stdout.fileHandleForReading.availableData, encoding: .utf8) ?? "No output")
        print("stderr:")
        print(String(data: stderr.fileHandleForReading.availableData, encoding: .utf8) ?? "No output")
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        // The tests get flaky without a small delay between them--some artifact of the Python server running in a subprocess, maybe.
        Thread.sleep(until: Date().addingTimeInterval(0.1))
    }

    let serverProxy: ServerProxy = .init(session: .shared, url: URL(string: "http://localhost:8000/RPC2")!)

    private func assert<T: Decodable & Equatable>(
        methodName: String,
        params: [some Encodable],
        expectedResult: T,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "async call finished")
        serverProxy.execute(methodName: methodName, params: params) { (result: ServerProxy.Result<T>) in
            result.assertHasValue(expectedResult, file: file, line: line)
            expectation.fulfill()
        }
        if case .timedOut = XCTWaiter().wait(for: [expectation], timeout: timeout) {
            XCTFail("timed out waiting for async call to finish", file: file, line: line)
        }
    }

    private func assert(
        methodName: String,
        params: [some Encodable],
        expectedResult: some Decodable & Equatable,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        await serverProxy.execute(methodName: methodName, params: params)
            .assertHasValue(expectedResult, file: file, line: line)
    }

    func testValidMethods() {
        assert(methodName: "pow", params: [2, 3] as [Int32], expectedResult: Int32(8))
        assert(methodName: "add", params: [2, 3] as [Int32], expectedResult: Int32(5))
        assert(methodName: "div", params: [5, 2] as [Int32], expectedResult: Int32(2))
    }

    func testValidMethodsAsync() async {
        await assert(methodName: "pow", params: [2, 3] as [Int32], expectedResult: Int32(8))
        await assert(methodName: "add", params: [2, 3] as [Int32], expectedResult: Int32(5))
        await assert(methodName: "div", params: [5, 2] as [Int32], expectedResult: Int32(2))
    }

    func testInvalidMethod() {
        let expectation = XCTestExpectation(description: "async call finished")
        serverProxy.execute(methodName: "foo") { (result: ServerProxy.Result<String>) in
            result.assertFault(expectedCode: 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testInvalidMethodAsync() async {
        await (serverProxy.execute(methodName: "foo") as ServerProxy.Result<String>)
            .assertFault(expectedCode: 1)
    }

    func testMissingParameters() {
        let expectation = XCTestExpectation(description: "async call finished")
        serverProxy.execute(methodName: "add") { (result: ServerProxy.Result<String>) in
            result.assertFault(expectedCode: 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testMissingParametersAsync() async {
        await (serverProxy.execute(methodName: "add") as ServerProxy.Result<String>)
            .assertFault(expectedCode: 1)
    }

    func testBadParameters() {
        let expectation = XCTestExpectation(description: "async call finished")
        serverProxy.execute(methodName: "pow", params: ["A", "B"]) { (result: ServerProxy.Result<String>) in
            result.assertFault(expectedCode: 1)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testBadParametersAsync() async {
        await (serverProxy.execute(methodName: "pow", params: ["A", "B"]) as ServerProxy.Result<String>)
            .assertFault(expectedCode: 1)
    }

    func testUnconnectableServer() {
        guard let url = URL(string: "http://localhost:9999/") else { fatalError() }
        let serverProxy = ServerProxy(session: URLSession.shared, url: url)
        let expectation = XCTestExpectation(description: "async call finished")
        serverProxy.foo { (result: ServerProxy.Result<String>) in
            result.assertNetworkError(expectedDomain: NSURLErrorDomain, expectedCode: NSURLErrorCannotConnectToHost)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testUnconnectableServerAsync() async {
        guard let url = URL(string: "http://localhost:9999/") else { fatalError() }
        let serverProxy = ServerProxy(session: URLSession.shared, url: url)
        await (serverProxy.foo() as ServerProxy.Result<String>)
            .assertNetworkError(expectedDomain: NSURLErrorDomain, expectedCode: NSURLErrorCannotConnectToHost)
    }

    func testBadPathOnServer() {
        guard let url = URL(string: "http://localhost:8000/foo") else { fatalError() }
        let serverProxy = ServerProxy(session: URLSession.shared, url: url)
        let expectation = XCTestExpectation(description: "async call finished")
        serverProxy.foo { (result: ServerProxy.Result<String>) in
            result.assertHTTPError(expectedCode: 404)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }

    func testBadPathOnServerAsync() async {
        guard let url = URL(string: "http://localhost:8000/foo") else { fatalError() }
        let serverProxy = ServerProxy(session: URLSession.shared, url: url)
        await (serverProxy.foo() as ServerProxy.Result<String>)
            .assertHTTPError(expectedCode: 404)
    }

    func testSubscriptCalling() {
        let expectation1 = XCTestExpectation(description: "async call finished")
        serverProxy.add([2, 3] as [Int32]) { (result: ServerProxy.Result<Int32>) in
            result.assertHasValue(5)
            expectation1.fulfill()
        }
        let expectation2 = XCTestExpectation(description: "async call finished")
        serverProxy.add(Int32(2), Int32(3))({ (result: ServerProxy.Result<Int32>) in
            result.assertHasValue(5)
            expectation2.fulfill()
        })
        let expectation3 = XCTestExpectation(description: "async call finished")
        serverProxy.add { (result: ServerProxy.Result<String>) in
            result.assertFault(expectedCode: 1)
            expectation3.fulfill()
        }
        wait(for: [expectation1, expectation2], timeout: timeout)
    }

    func testSubscriptCallingAsync() async {
        await (serverProxy.add(Int32(2), Int32(3)))
            .assertHasValue(Int32(5))
        await (serverProxy.add() as ServerProxy.Result<String>)
            .assertFault(expectedCode: 1)
    }
}
