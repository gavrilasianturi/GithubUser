//
//  SearchViewModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import Foundation

internal class SearchViewModel {
    internal enum SortType: String {
        case ascending
        case descending
        case none
    }
    
    @Published var sortType: SortType = .none
    @Published var query: String = ""
    @Published var favoriteUsers = Set<FavoriteUserData>()
    @Published private(set) var users: [User] = []
    @Published private(set) var errorMessage: String = ""
    
    private var cancellables: Set<AnyCancellable> = []
    
    private let networkManager: GithubNetworkManager
    private let favoriteStorage: FavoriteUserStorage
    private let debounce: Int
    
    internal init(
        networkManager: GithubNetworkManager = LiveGithubNetworkManager(),
        debounce: Int = 300,
        favoriteUserStorage: FavoriteUserStorage = CoreDataFavoriteUserStorage()
    ) {
        self.networkManager = networkManager
        self.debounce = debounce
        self.favoriteStorage = favoriteUserStorage
        
        loadFavoriteStates()
        setupSearch()
        setupSortedItems()
    }
    
    private func setupSearch() {
        $query
            .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
            .flatMap({ [weak self] query -> AnyPublisher<[User], NetworkError> in
                guard let self else { return Fail(error: NetworkError.others("")).eraseToAnyPublisher() }
                
                let finalQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                guard !finalQuery.isEmpty else {
                    return Just([])
                        .setFailureType(to: NetworkError.self)
                        .eraseToAnyPublisher()
                }
                
                return self.networkManager
                    .getSearchResult(query: query)
                    .map { [weak self] response -> [User] in
                        guard let self else { return [] }
                        return sort(sortType, from: response.items)
                    }
                    .eraseToAnyPublisher()
            })
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    switch completion {
                    case .finished:
                        self.errorMessage = ""
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.users = []
                    }
                },
                receiveValue: { [weak self] userResponse in
                    guard let self else { return }
                    
                    users = userResponse.compactMap { [weak self] user -> User? in
                        guard let self else { return user }
                        var mutatedUser = user
                        mutatedUser.isLiked = favoriteUsers.contains(where: { $0.id == user.id && $0.username == user.login })
                        return mutatedUser
                    }
                    
                    errorMessage = ""
                }
            )
            .store(in: &cancellables)
    }
    
    private func setupSortedItems() {
        $sortType
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] sortType in
                    guard let self else { return }
                    users = sort(sortType, from: users)
                }
            ).store(in: &cancellables)
    }
    
    internal func setFavorite(for user: User) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        
        let item = users[index]
        
        let storageAction = item.isLiked ? favoriteStorage.removeFavorite(id: item.id, username: item.login) : favoriteStorage.saveFavorite(id: item.id, username: item.login)
        
        storageAction
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    guard let self, let index = users.firstIndex(where: { $0.id == user.id }) else { return }
                    users[index].isLiked.toggle()
                    loadFavoriteStates()
                }
            ).store(in: &cancellables)
    }
    
    private func loadFavoriteStates() {
        favoriteStorage.getAllFavorites()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] favorites in
                    guard let self else { return }
                    favoriteUsers = Set(favorites)
                }
            )
            .store(in: &cancellables)
    }
    
    private func sort(_ type: SortType, from items: [User]) -> [User] {
        switch sortType {
        case .ascending:
            return items.sorted(by: { $0.login.lowercased() < $1.login.lowercased() })
        case .descending:
            return items.sorted(by: { $0.login.lowercased() > $1.login.lowercased() })
        case .none:
            return items
        }
    }
}
