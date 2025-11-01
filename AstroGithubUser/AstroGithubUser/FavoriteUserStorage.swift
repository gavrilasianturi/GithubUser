//
//  Favorite.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import CoreData
import Foundation

internal struct FavoriteUserData: Codable, Hashable {
    internal let id: Int
    internal let username: String
}

internal protocol FavoriteUserStorage {
    func saveFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError>
    func removeFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError>
    func getAllFavorites() -> AnyPublisher<[FavoriteUserData], NetworkError>
}

internal class CoreDataFavoriteUserStorage: FavoriteUserStorage {
    private let container: NSPersistentContainer
    
    internal init() {
        self.container = NSPersistentContainer(name: "FavoriteUsers")
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
    
    internal func saveFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError> {
        let context = self.container.viewContext
        
        let request: NSFetchRequest<FavoriteUser> = FavoriteUser.fetchRequest()
        
        do {
            let allFavorites = try context.fetch(request)
            let existing = allFavorites.filter { $0.id == id && $0.username == username }
            
            if existing.isEmpty {
                let favorite = FavoriteUser(context: context)
                favorite.id = Int64(id)
                favorite.username = username
            }
            
            try context.save()
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: NetworkError.others(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    internal func removeFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError> {
        let context = self.container.viewContext
        
        let request: NSFetchRequest<FavoriteUser> = FavoriteUser.fetchRequest()
        
        do {
            let allFavorites = try context.fetch(request)
            
            allFavorites.forEach { user in
                guard user.id == id, user.username == username else { return }
                context.delete(user)
            }
            
            try context.save()
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: NetworkError.others(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    internal func getAllFavorites() -> AnyPublisher<[FavoriteUserData], NetworkError> {
        let context = container.viewContext
        let request: NSFetchRequest<FavoriteUser> = FavoriteUser.fetchRequest()
        
        do {
            let favorites = try context.fetch(request)
            let favoriteUsers = favorites.map { FavoriteUserData(id: Int($0.id), username: $0.username ?? "") }
            
            return Just(favoriteUsers)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: NetworkError.others(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
}
