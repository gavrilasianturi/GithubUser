//
//  MockGlobalStorage.swift
//  AstroGithubUserTests
//
//  Created by ByteDance on 02/11/25.
//

import Combine
import Foundation

@testable import AstroGithubUser

internal class MockGlobalStorage: GlobalStorage {
    internal var mockType: MockType = .empty
    internal var sortType: SearchViewModel.SortType = .none
    
    internal func saveFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError> {
        switch mockType {
        case .normal, .empty:
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        case .error:
            return Fail(error: NetworkError.others("Fail to save"))
                .eraseToAnyPublisher()
        }
    }
    
    internal func removeFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError> {
        switch mockType {
        case .normal, .empty:
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        case .error:
            return Fail(error: NetworkError.others("Fail to remove"))
                .eraseToAnyPublisher()
        }
    }
    
    internal func getAllFavorites() -> AnyPublisher<[FavoriteUserData], NetworkError> {
        switch mockType {
        case .normal:
            let favoriteUsers = [
                FavoriteUserData(id: 1, username: "satu")
            ]
            
            return Just(favoriteUsers)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
            
        case .empty:
            return Just([])
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
            
        case .error:
            return Fail(error: NetworkError.others("Fail to remove"))
                .eraseToAnyPublisher()
        }
    }
    
    internal func saveUserPreference(_ preference: UserPreferenceData) -> AnyPublisher<Void, NetworkError> {
        switch mockType {
        case .normal, .empty:
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
            
        case .error:
            return Fail(error: NetworkError.others("Fail to remove"))
                .eraseToAnyPublisher()
        }
    }
    
    internal func getUserPreference() -> AnyPublisher<UserPreferenceData?, NetworkError> {
        switch mockType {
        case .normal:
            let userPreference = UserPreferenceData(sortType: sortType.rawValue)
            return Just(userPreference)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
            
        case .empty:
            return Just(nil)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        case .error:
            return Fail(error: NetworkError.others("Fail to get user prefence"))
                .eraseToAnyPublisher()
        }
    }
}
