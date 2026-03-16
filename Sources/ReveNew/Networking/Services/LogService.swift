//
//  CloudflareServices.swift
//  Vision Pal
//
//  Created by Pietro Messineo on 03/03/24.
//

import Foundation

struct LogService: HTTPClient {
    private let host: String
    private let port: Int?
    private let pathPrefix: String?
    
    init(host: String, port: Int? = nil, pathPrefix: String? = nil) {
        self.host = host
        self.port = port
        self.pathPrefix = pathPrefix
    }
    
    func logPurchase(productInfo: ProductInfo) async throws -> LogResponse {
        return try await request(
            endpoint: LogEndpoint.logPurchase(productInfo: productInfo, host: host, port: port, pathPrefix: pathPrefix),
            responseModel: LogResponse.self
        )
    }
    
    func logDownload(userId: String, appName: String) async throws -> LogResponse {
        return try await request(
            endpoint: LogEndpoint.logDownload(userId: userId, appName: appName, host: host, port: port, pathPrefix: pathPrefix),
            responseModel: LogResponse.self
        )
    }
}
