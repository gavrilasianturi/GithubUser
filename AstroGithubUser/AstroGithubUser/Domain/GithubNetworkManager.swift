//
//  GithubNetworkManager.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import Foundation
import SharedServices

internal protocol GithubNetworkManager {
    func getSearchResult(query: String, page: Int) -> AnyPublisher<UserResponse, NetworkError>
}

internal final class LiveGithubNetworkManager: GithubNetworkManager {
    internal let networkService = NetworkService.shared
    
    internal init() {}
    
    internal func getSearchResult(query: String, page: Int) -> AnyPublisher<UserResponse, NetworkError> {
        guard let url = URL(string: "https://api.github.com/search/users?q=\(query)&page=\(page)") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
                
        let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("Request URL: \(request)")
        
        return networkService.fetch(request)
    }
}
