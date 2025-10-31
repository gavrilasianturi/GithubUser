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
                guard
                    let httpResponse = response as? HTTPURLResponse,
                    httpResponse.statusCode == 200
                else { throw NetworkError.networkError }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                (error as? NetworkError) ?? NetworkError.others(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
}

