// Copyright © 2024 Isaac Greenspan.  All rights reserved.

import Foundation
import XMLRPCCoder

@dynamicMemberLookup public struct ServerProxy {
    let session: URLSession
    let url: URL
    let coder: XMLRPCCoderProtocol

    public init(session: URLSession, url: URL, coder: XMLRPCCoderProtocol = XMLRPCCoder()) {
        self.session = session
        self.url = url
        self.coder = coder
    }

    /// Possible errors when making a request to an XML-RPC server.
    public enum Error: Swift.Error {
        case responseParsing(ResponseParsingError)
        case noData
        case httpNotOK(HTTPURLResponse)
        case network(Swift.Error?)
        case internalInconsistency(Swift.Error)
    }

    public typealias Result<SuccessType: Decodable> = Swift.Result<SuccessType, Error>

    // MARK: - callback-based execution methods

    /// Make an XML-RPC call.
    /// - Parameters:
    ///   - methodName: The name of the method to call
    ///   - params: The parameters to pass to the method
    ///   - callback: The callback to invoke when the XML-RPC call is complete.
    // swiftformat:disable:next opaqueGenericParameters
    public func execute<D: Decodable>(methodName: String, params: [some Encodable]?, callback: Result<D>.Callback? = nil) {
        session.dataTask(with: urlRequest(methodName: methodName, params: params)) { data, response, error in
            self.dataTaskResponseHandler(data: data, response: response, error: error, callback: callback)
        }.resume()
    }

    /// Make an XML-RPC call.
    /// - Parameters:
    ///   - methodName: The name of the method to call
    ///   - callback: The callback to invoke when the XML-RPC call is complete.
    // swiftformat:disable:next opaqueGenericParameters
    public func execute<D: Decodable>(methodName: String, callback: Result<D>.Callback? = nil) {
        let params: [String]? = nil
        execute(methodName: methodName, params: params, callback: callback)
    }

    // MARK: - async/await execution methods

    /// Make an XML-RPC call.
    /// - Parameters:
    ///   - methodName: The name of the method to call
    ///   - params: The parameters to pass to the method
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func execute<D: Decodable>(methodName: String, params: [some Encodable]?) async -> Result<D> {
        do {
            let (data, response) = try await session.data(for: urlRequest(methodName: methodName, params: params))
            return dataTaskSuccessConverter(data: data, response: response)
        } catch {
            return .failure(.network(error))
        }
    }

    /// Make an XML-RPC call.
    /// - Parameters:
    ///   - methodName: The name of the method to call
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    public func execute<D: Decodable>(methodName: String) async -> Result<D> {
        let params: [String]? = nil
        return await execute(methodName: methodName, params: params)
    }
}

public extension ServerProxy {
    // For @dynamicMemberLookup to facilitate nicer-looking method calls.

    // MARK: - callback-based @dynamicMemberLookup execution

    /// Allows calling `serverProxy.methodName(parametersArray) { result in … }`
    subscript<E: Encodable, D: Decodable>(dynamicMember methodName: String) -> (_ params: [E]?, _ callback: Result<D>.Callback?) -> Void {
        { params, callback in
            self.execute(methodName: methodName, params: params, callback: callback)
        }
    }

    /// Allows calling `serverProxy.methodName() { result in … }`
    subscript<D: Decodable>(dynamicMember methodName: String) -> (_ callback: Result<D>.Callback?) -> Void {
        { callback in
            let params: [String]? = nil
            self.execute(methodName: methodName, params: params, callback: callback)
        }
    }

    /// Allows calling `serverProxy.methodName(param1, param2, …)({ result in … })`
    subscript<E: Encodable, D: Decodable>(dynamicMember methodName: String) -> (_ params: E...) -> (_ callback: Result<D>.Callback?) -> Void {
        { (params: E...) in
            { callback in
                self.execute(methodName: methodName, params: params, callback: callback)
            }
        }
    }

    // MARK: - async/await @dynamicMemberLookup execution

    // No way to differentiate `await serverProxy.methodName(parametersArray)` from the variadic version, so not
    // implementing it.

    /// Allows calling `await serverProxy.methodName()`
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    subscript<D: Decodable>(dynamicMember methodName: String) -> () async -> Result<D> {
        {
            await self.execute(methodName: methodName, params: nil as [String]?)
        }
    }

    /// Allows calling `await serverProxy.methodName(param1, param2, …)`
    @available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
    subscript<E: Encodable, D: Decodable>(dynamicMember methodName: String) -> (_ params: E...) async -> Result<D> {
        { (params: E...) in
            await self.execute(methodName: methodName, params: params)
        }
    }
}

// MARK: -

public extension Swift.Result {
    typealias Callback = (Result) -> Void
}

/// Protocol to allow substitution of XML-RPC coders other than `XMLRPCCoder`.
public protocol XMLRPCCoderProtocol {
    /// Returns an XML-RPC style XML representation of the value you supply.
    /// - Parameter value: The value to encode as XML-RPC style XML.
    /// - Returns: An `XMLElement` containing the encoded XML.
    func encode(_: some Encodable) throws -> XMLElement

    /// Returns a value of the type you specify, decoded from XML-RPC style XML.
    /// - Parameters:
    ///   - type: The type of the value to decode from the supplied XML-RPC style XML.
    ///   - raw: An `XMLElement` containing the XML.
    /// - Returns: A value of the specified type, if the decoder can parse the XML.
    func decode<D: Decodable>(toType _: D.Type, from _: XMLElement) throws -> D
}

extension XMLRPCCoder: XMLRPCCoderProtocol {}

// MARK: - internal request/response handling helpers

extension ServerProxy {
    func urlRequest(methodName: String, params: [some Encodable]?) -> URLRequest {
        let xmlrpcRequest = Request(methodName: methodName, params: params)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? xmlrpcRequest.encoded().xmlData
        request.setValue("text/xml", forHTTPHeaderField: "Content-type")
        return request
    }

    // swiftformat:disable:next opaqueGenericParameters
    func dataTaskResponseHandler<D: Decodable>(
        data: Data?,
        response: URLResponse?,
        error: Swift.Error?,
        callback: Result<D>.Callback?
    ) {
        guard let response, error == nil else {
            callback?(.failure(.network(error)))
            return
        }
        callback?(dataTaskSuccessConverter(data: data, response: response))
    }

    func dataTaskSuccessConverter<D: Decodable>(data: Data?, response: URLResponse) -> Result<D> {
        guard let response = response as? HTTPURLResponse else {
            return .failure(.network(nil))
        }
        guard response.statusCode == 200 else {
            return .failure(.httpNotOK(response))
        }
        guard let data else {
            return .failure(.noData)
        }
        do {
            let result: D = try data.xmlrpcParseResponse(coder: coder)
            return .success(result)
        } catch let error as ResponseParsingError {
            return .failure(.responseParsing(error))
        } catch let error as DecodingError {
            return .failure(.responseParsing(.decodingError(error)))
        } catch {
            // xmlrpcParseResponse() should not throw an error that isn't ResponseParsingError
            return .failure(.internalInconsistency(error))
        }
    }
}
