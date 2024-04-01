// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import XCTest
import XMLRPCClient

public extension Result where Success: Equatable {
    /// Assert that the receiver represents success with the given value.
    /// - Parameters:
    ///   - expectedValue: The value the result should contain
    ///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the failure occurs. The default is the line number where you call this function.
    func assertHasValue(
        _ expectedValue: Success,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            let resultValue = try get()
            XCTAssertEqual(resultValue, expectedValue, file: file, line: line)
        } catch {
            XCTFail("error: \(error)", file: file, line: line)
        }
    }
}

public extension Result {
    /// Assert that the receiver represents an XML-RPC fault with the given code (if provided) and message (if provided).
    /// - Parameters:
    ///   - expectedCode: If provided, the code the fault should contain.
    ///   - expectedMessage: If provided, the message the fault should contain.
    ///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the failure occurs. The default is the line number where you call this function.
    func assertFault(
        expectedCode: Int32? = nil,
        expectedMessage: String? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        do {
            _ = try get()
            XCTFail("unexpected success", file: file, line: line)
        } catch let ServerProxy.Error.responseParsing(.fault(code, message)) {
            if let expectedCode {
                XCTAssertEqual(expectedCode, code, file: file, line: line)
            }
            if let expectedMessage {
                XCTAssertEqual(expectedMessage, message, file: file, line: line)
            }
        } catch {
            XCTFail("error: \(error)", file: file, line: line)
        }
    }

    /// Assert that the receiver represents an HTTP error.
    /// - Parameters:
    ///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the failure occurs. The default is the line number where you call this function.
    ///   - responseHandler: A block for making further assertions about the HTTP response.
    func assertHTTPError(
        file: StaticString = #file,
        line: UInt = #line,
        _ responseHandler: (HTTPURLResponse) -> Void
    ) {
        do {
            _ = try get()
            XCTFail("unexpected success", file: file, line: line)
        } catch let ServerProxy.Error.httpNotOK(response) {
            responseHandler(response)
        } catch {
            XCTFail("error: \(error)", file: file, line: line)
        }
    }

    /// Assert that the receiver represents an HTTP error with the given code (if provided).
    /// - Parameters:
    ///   - expectedCode: If provided, the code the HTTP error should be.
    ///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the failure occurs. The default is the line number where you call this function.
    func assertHTTPError(
        expectedCode: Int? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assertHTTPError(file: file, line: line) { response in
            if let expectedCode {
                XCTAssertEqual(response.statusCode, expectedCode, file: file, line: line)
            }
        }
    }

    /// Assert that the receiver represents a network error.
    /// - Parameters:
    ///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the failure occurs. The default is the line number where you call this function.
    ///   - errorHandler: A block for making further assertions about the optional inner error.
    func assertNetworkError(
        file: StaticString = #file,
        line: UInt = #line,
        _ errorHandler: (Error?) -> Void
    ) {
        do {
            _ = try get()
            XCTFail("unexpected success", file: file, line: line)
        } catch let ServerProxy.Error.network(error) {
            errorHandler(error)
        } catch {
            XCTFail("error: \(error)", file: file, line: line)
        }
    }

    /// Assert that the receiver represents a network error with an inner `NSError`.
    /// - Parameters:
    ///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the failure occurs. The default is the line number where you call this function.
    ///   - errorHandler: A block for making further assertions about the inner `NSError`.
    func assertNetworkError(
        file: StaticString = #file,
        line: UInt = #line,
        _ errorHandler: (NSError) -> Void
    ) {
        assertNetworkError { (error: Error?) in
            guard let error else {
                XCTFail("no inner error", file: file, line: line)
                return
            }
            errorHandler(error as NSError)
        }
    }

    /// Assert that the receiver represents a network error with an inner `NSError` with the given domain (if provided)
    /// and code (if provided).
    /// - Parameters:
    ///   - expectedDomain: If provided, the domain the inner error should have.
    ///   - expectedCode: If provided, the code the inner error should have.
    ///   - file: The file where the failure occurs. The default is the filename of the test case where you call this function.
    ///   - line: The line number where the failure occurs. The default is the line number where you call this function.
    func assertNetworkError(
        expectedDomain: String? = nil,
        expectedCode: Int? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assertNetworkError(file: file, line: line) { nsError in
            if let expectedDomain {
                XCTAssertEqual(nsError.domain, expectedDomain, file: file, line: line)
            }
            if let expectedCode {
                XCTAssertEqual(nsError.code, expectedCode, file: file, line: line)
            }
        }
    }
}
