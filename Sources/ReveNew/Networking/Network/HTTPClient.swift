//
//  HTTPClient.swift
//  Gravel
//
//  Created by Pietro Messineo on 30/01/24.
//

import Foundation

protocol Endpoint {
    var scheme: String { get }
    var host: String { get }
    var path: String { get }
    var method: RequestMethod { get }
    var header: [String: String]? { get }
    var body: [String: Any]? { get }
    var queryItems: [URLQueryItem]? { get }
    var port: Int { get }
    
    func buildRequestBody() -> (Data?, contentType: String?)
}

enum RequestMethod: String {
    case delete = "DELETE"
    case get = "GET"
    case patch = "PATCH"
    case post = "POST"
    case put = "PUT"
}

extension Endpoint {
    var scheme: String {
        return "http"
    }
}

protocol HTTPClient {
    func request<T: Decodable>(endpoint: Endpoint, responseModel: T.Type, decoder: JSONDecoder?) async throws -> T
}

extension HTTPClient {
    
    func request<T: Decodable>(
        endpoint: Endpoint,
        responseModel: T.Type,
        decoder: JSONDecoder? = JSONDecoder()
    ) async throws -> T {
        var urlComponents = URLComponents()
        urlComponents.scheme = endpoint.scheme
        urlComponents.host = endpoint.host
        urlComponents.path = endpoint.path
        urlComponents.port = endpoint.port
        
        if let queryItems = endpoint.queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw RequestError.invalidURL
        }
        
        var request = URLRequest(url: url, timeoutInterval: 120)
        
        // Methods and headers
        request.httpMethod = endpoint.method.rawValue
        
        // Dynamic iterate between headers
        if let headers = endpoint.header {
            for header in headers {
                request.addValue(header.value, forHTTPHeaderField: header.key)
            }
        }
        
        let (bodyData, contentType) = endpoint.buildRequestBody()

        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }

        if let bodyData = bodyData {
            request.httpBody = bodyData
        }
        
        let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
        
        guard let response = response as? HTTPURLResponse else {
            throw RequestError.noResponse
        }
        
        switch response.statusCode {
        case 200 ... 299:
            do {
                return try decoder!.decode(responseModel, from: data)
            } catch let DecodingError.dataCorrupted(context) {
                print("Data corrupted: \(context)")
            } catch let DecodingError.keyNotFound(key, context) {
                print("Key '\(key)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
            } catch let DecodingError.typeMismatch(type, context)  {
                print("Type '\(type)' mismatch: \(context.debugDescription), codingPath: \(context.codingPath)")
            } catch let DecodingError.valueNotFound(value, context) {
                print("Value '\(value)' not found: \(context.debugDescription), codingPath: \(context.codingPath)")
            } catch {
                print("Unexpected error: \(error.localizedDescription)")
            }
            throw RequestError.decode
        case 401:
            throw RequestError.unauthorized
        case 404:
            throw RequestError.notFound
        case 409:
            throw RequestError.emailInUse
        case 400, 500:
            do {
                return try decoder!.decode(responseModel, from: data)
            } catch {
                print(error.localizedDescription)
                throw RequestError.decode
            }
        default:
            throw RequestError.unexpectedStatusCode
        }
    }
}

enum RequestError: Error {
    case decode
    case invalidURL
    case noResponse
    case unauthorized
    case unexpectedStatusCode
    case unknown
    case notFound
    case emailInUse

    var customMessage: String {
        switch self {
        case .decode:
            return "Decode error"
        case .unauthorized:
            return "Session expired"
        case .notFound:
            return "User not found"
        case .emailInUse:
            return "Email already in use"
        default:
            return "Unknown error"
        }
    }
}
