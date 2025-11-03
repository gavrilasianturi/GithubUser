//
//  MockGithubNetworkManager.swift
//  AstroGithubUserTests
//
//  Created by Gavrila on 02/11/25.
//

import Combine
import Foundation
import SharedServices

@testable import AstroGithubUser

internal final class MockGithubNetworkManager: GithubNetworkManager {
    internal var mockType: MockType = .normal
    
    internal func getSearchResult(query: String, page: Int) -> AnyPublisher<UserResponse, NetworkError> {
        switch mockType {
        case .normal:
            let mockResponse = MockUserResponse.normal
            return Just(mockResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
            
        case .empty:
            let mockResponse = MockUserResponse.empty
            return Just(mockResponse)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
            
        case .error:
            return Fail(error: NetworkError.others("Fail to fetch data"))
                .eraseToAnyPublisher()
        }
    }
}
