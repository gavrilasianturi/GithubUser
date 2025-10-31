//
//  GithubNetworkManager.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import Foundation

internal protocol GithubNetworkManager {
    func getSearchResult(query: String) -> AnyPublisher<UserResponse, NetworkError>
}

internal final class LiveGithubNetworkManager: GithubNetworkManager {
    
    private let networkService = NetworkService()
    
    internal init() {}
    
    internal func getSearchResult(query: String) -> AnyPublisher<UserResponse, NetworkError> {
        guard let url = URL(string: "https://api.github.com/search/users?q=\(query)") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return networkService.fetch(URLRequest(url: url))
    }
}
