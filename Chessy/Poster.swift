//
//  Poster.swift
//  Chessy
//
//  Created by Nathan Merz on 9/14/24.
//

import Foundation


class Poster {
    private static func makeRequest(rawRequest: URLRequest, postContent: Optional<Encodable>) throws -> URLRequest {
        var request = rawRequest
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if postContent != nil {
            request.httpBody = try JSONEncoder().encode(postContent!)
            print(String(data: request.httpBody!, encoding: .utf8)!)
        }
        return request
    }
    
    static func postFor<T: Decodable>(_ _: T.Type, request: URLRequest, postString: String) async throws -> T {
        let session = URLSession.init(configuration: URLSessionConfiguration.default)
        defer {session.finishTasksAndInvalidate()}
        print(request)
        var request = try makeRequest(rawRequest: request, postContent: nil)
        request.httpBody = postString.data(using: .utf8)
        let (data, resp) = try await session.data(for: request)
        print(resp)
        print(String(data: data, encoding: .utf8) ?? "")
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    static func postFor<T: Decodable>(_ _: T.Type, request: URLRequest, postContent: Optional<Encodable> = nil) async throws -> T {
        let session = URLSession.init(configuration: URLSessionConfiguration.default)
        defer {session.finishTasksAndInvalidate()}
        print(request)
        let (data, resp) = try await session.data(for: try makeRequest(rawRequest: request, postContent: postContent))
        print(resp)
        print(String(data: data, encoding: .utf8) ?? "")
        return try JSONDecoder().decode(T.self, from: data)
    }
    
}
