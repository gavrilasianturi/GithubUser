//
//  NetworkService.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import Foundation

internal class NetworkService {
    public static let shared = NetworkService()
    
    internal func fetch<T: Decodable>(_ request: URLRequest) -> AnyPublisher<T, NetworkError> {
        URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                print("status code", (response as? HTTPURLResponse)?.statusCode)
                guard
                    let httpRespones = response as? HTTPURLResponse
                else { throw NetworkError.networkError }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                NetworkError.others(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
}

