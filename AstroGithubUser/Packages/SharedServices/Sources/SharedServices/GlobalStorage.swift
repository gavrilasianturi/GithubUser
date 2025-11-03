//
//  Favorite.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import CoreData
import Foundation

public struct FavoriteUserData: Codable, Hashable {
    public let id: Int
    public let username: String
    
    public init(id: Int, username: String) {
        self.id = id
        self.username = username
    }
}

public struct UserPreferenceData: Codable, Hashable {
    public var sortType: String
    
    public init(sortType: String) {
        self.sortType = sortType
    }
}

public protocol GlobalStorage {
    func saveFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError>
    func removeFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError>
    func getAllFavorites() -> AnyPublisher<[FavoriteUserData], NetworkError>
    func saveUserPreference(_ preference: UserPreferenceData) -> AnyPublisher<Void, NetworkError>
    func getUserPreference() -> AnyPublisher<UserPreferenceData?, NetworkError>
}

public class CoreDataGlobalStorage: GlobalStorage {
    private let container: NSPersistentContainer
    
    public init() {
        let bundle = Bundle.module
        
        guard let modelURL = bundle.url(forResource: "GlobalStorage", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load GlobalStorage.xcdatamodeld from SharedServices bundle")
        }
        
        self.container = NSPersistentContainer(name: "GlobalStorage", managedObjectModel: model)
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
    }
    
    public func saveFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError> {
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
    
    public func removeFavorite(id: Int, username: String) -> AnyPublisher<Void, NetworkError> {
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
    
    public func getAllFavorites() -> AnyPublisher<[FavoriteUserData], NetworkError> {
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
    
    public func saveUserPreference(_ preference: UserPreferenceData) -> AnyPublisher<Void, NetworkError> {
        let context = self.container.viewContext
        
        let request: NSFetchRequest<Preference> = Preference.fetchRequest()
        
        do {
            let currentPreference = try context.fetch(request)
            currentPreference.forEach { preference in
                context.delete(preference)
            }
            
            let newPreference = Preference(context: context)
            newPreference.sortType = preference.sortType
            
            try context.save()
            return Just(())
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: NetworkError.others(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
    
    public func getUserPreference() -> AnyPublisher<UserPreferenceData?, NetworkError> {
        let context = self.container.viewContext
        
        let request: NSFetchRequest<Preference> = Preference.fetchRequest()
        
        do {
            let currentPreference = try context.fetch(request)
            
            let preference: UserPreferenceData?
            if let storagePreference = currentPreference.first {
                preference = UserPreferenceData(sortType: storagePreference.sortType ?? "")
            } else {
                preference = nil
            }
            
            return Just(preference)
                .setFailureType(to: NetworkError.self)
                .eraseToAnyPublisher()
        } catch {
            return Fail(error: NetworkError.others(error.localizedDescription))
                .eraseToAnyPublisher()
        }
    }
}
