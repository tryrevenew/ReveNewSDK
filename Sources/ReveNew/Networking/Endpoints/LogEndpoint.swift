//
//  CloudFlareEndpoint.swift
//  Vision Pal
//
//  Created by Pietro Messineo on 03/03/24.
//

import Foundation


enum LogEndpoint {
    case logPurchase(productInfo: ProductInfo, host: String, port: Int)
    case logDownload(userId: String, appName: String, host: String, port: Int)
}

extension LogEndpoint: Endpoint {
    var host: String {
        switch self {
        case .logPurchase(_, let host, _),
             .logDownload(_, _, let host, _):
            return host
        }
    }
    
    var port: Int {
        switch self {
        case .logPurchase(_, _, let port),
             .logDownload(_, _, _, let port):
            return port
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .logPurchase, .logDownload:
            return nil
        }
    }
    
    var path: String {
        switch self {
        case .logPurchase:
            return "/api/v1/log-purchase"
        case .logDownload:
            return "/api/v1/log-download"
        }
    }

    var method: RequestMethod {
        switch self {
        case .logPurchase, .logDownload:
            return .post
        }
    }

    var header: [String: String]? {
        switch self {
        case .logPurchase, .logDownload:
            return nil
        }
    }
    
    var body: [String: Any]? {
        switch self {
        case .logPurchase(let productInfo, _, _):
            return [
                "currencyCode": productInfo.currencyCode,
                "price": productInfo.price,
                "priceFormatted": productInfo.priceFormatted,
                "kind": productInfo.kind,
                "isSandbox": productInfo.isSandbox,
                "appName": productInfo.appName,
                "storeFront": productInfo.storeFront
            ]
        case .logDownload(let userId, let appName, _, _):
            return [
                "userId": userId,
                "appName": appName
            ]
        }
    }
    
    func buildRequestBody() -> (Data?, contentType: String?) {
        switch self {
        default:
            if let body = body {
                let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [])
                return (jsonData, "application/json")
            } else {
                return (nil, "application/json")
            }
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

struct ProductInfo {
    let currencyCode: String
    let price: Decimal
    let priceFormatted: String
    let kind: String
    let isSandbox: Bool
    let appName: String
    let storeFront: String
}
