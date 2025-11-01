//
//  SearchViewModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import Foundation

// TODO: UPDATE LAYOUTTYPE (LOADING, EMPTY RESULT, ERROR FROM API)
// TODO: MODULARRR
internal class SearchViewModel {
    internal enum SortType: String {
        case ascending
        case descending
        case none
    }
    
    @Published var sortType: SortType = .none
    @Published var query: String = ""
    @Published private(set) var users: [User] = []
    @Published private(set) var errorMessage: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var userPreference: UserPreferenceData?
    
    internal let loadMoreSubject = PassthroughSubject<Void, Never>()
    internal let updateSortSubject = PassthroughSubject<SortType, Never>()
    
    private(set) var favoriteUsers = Set<FavoriteUserData>()
    
    private var pageNumber: Int = 1
    private var previousQuery: String = ""
    
    private var cancellables: Set<AnyCancellable> = []
    
    private let networkManager: GithubNetworkManager
    private let globalStorage: GlobalStorage
    private let debounce: Int
    
    internal init(
        networkManager: GithubNetworkManager = LiveGithubNetworkManager(),
        debounce: Int = 300,
        globalStorage: GlobalStorage = CoreDataGlobalStorage()
    ) {
        self.networkManager = networkManager
        self.debounce = debounce
        self.globalStorage = globalStorage
        
        loadFavoriteStates()
        loadUserPreferenceState()
        setupSearch()
        setupSortedItems()
    }
    
    internal func setFavorite(for user: User) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        
        let item = users[index]
        
        let storageAction = item.isLiked ? globalStorage.removeFavorite(id: item.id, username: item.login) : globalStorage.saveFavorite(id: item.id, username: item.login)
        
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
    
    private func setupSearch() {
        let queryRequest = $query
            .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
            .map { [weak self] query -> (String, Int) in
                guard let self else { return ("", 1) }
                pageNumber = 1
                isLoading = true
                return (query, pageNumber)
            }
        
        let loadMoreRequest = loadMoreSubject
            .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
            .map { [weak self] _ -> (String, Int) in
                guard let self else { return ("", 1) }
                pageNumber += 1
                isLoading = true
                return (query, pageNumber)
            }
        
        Publishers.Merge(
            queryRequest,
            loadMoreRequest
        )
        .removeDuplicates(by: { old, new in
            old.0 == new.0 && old.1 == new.1
        })
        .filter { [weak self] _, _ in
            guard let self else { return false }
            return isLoading
        }
        .map { [weak self] query, page -> AnyPublisher<[User], NetworkError> in
            guard let self, !query.isEmpty else {
                return Just([])
                    .setFailureType(to: NetworkError.self)
                    .eraseToAnyPublisher()
            }
            
            return networkManager
                .getSearchResult(query: query, page: page)
                .map { response in response.items }
                .handleEvents(
                    receiveCompletion: { [weak self] _ in
                        self?.isLoading = false
                    },
                    receiveCancel: { [weak self] in
                        self?.isLoading = false
                    }
                )
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                
                switch completion {
                case .finished:
                    self.errorMessage = ""
                case .failure(let error):
                    if users.isEmpty {
                        self.errorMessage = error.localizedDescription
                        self.users = []
                    }
                }
            },
            receiveValue: { [weak self] newUsers in
                guard let self else { return }
                
                if pageNumber > 1 {
                    let combinedUsers = users + newUsers
                    let finalUsers = generateFavoriteUsers(for: combinedUsers)
                    
                    users = sort(sortType, from: finalUsers)
                } else {
                    let finalUsers = generateFavoriteUsers(for: newUsers)
                    users = sort(sortType, from: finalUsers)
                }
                
                errorMessage = ""
            }
        )
        .store(in: &cancellables)
    }
    
    private func setupSortedItems() {
        updateSortSubject
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] latestSortType in
                    guard let self else { return }
                    
                    let preference: UserPreferenceData
                    
                    if var currentPreference = userPreference {
                        currentPreference.sortType = latestSortType.rawValue
                        preference = currentPreference
                    } else {
                        preference = UserPreferenceData(sortType: latestSortType.rawValue)
                    }
                    
                    globalStorage
                        .saveUserPreference(preference)
                        .receive(on: DispatchQueue.main)
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { [weak self] _ in
                                guard let self else { return }
                                loadUserPreferenceState()
                            }
                        ).store(in: &cancellables)
                }
            ).store(in: &cancellables)
        
        $sortType
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] type in
                guard let self else { return }
                users = sort(type, from: users)
            }).store(in: &cancellables)
    }
    
    private func generateFavoriteUsers(for users: [User]) -> [User] {
        users.compactMap { [weak self] user -> User? in
            guard let self else { return user }
            var mutatedUser = user
            mutatedUser.isLiked = favoriteUsers.contains(where: { $0.id == user.id && $0.username == user.login })
            return mutatedUser
        }
    }
    
    private func reset() {
        users = []
        pageNumber = 1
    }
    
    private func trimQuery(_ q: String) -> String {
        q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    private func loadFavoriteStates() {
        globalStorage.getAllFavorites()
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
    
    private func loadUserPreferenceState() {
        globalStorage.getUserPreference()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] preference in
                    guard let self else { return }
                    userPreference = preference
                }
            )
            .store(in: &cancellables)
        
        $userPreference
            .sink(receiveValue: { [weak self] preference in
                guard let self else { return }
                if let sortOption = preference?.sortType {
                    sortType = SortType(rawValue: sortOption) ?? .none
                }
            }).store(in: &cancellables)
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
