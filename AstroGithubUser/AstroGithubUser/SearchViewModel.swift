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

internal enum Section {
    case main
}

internal enum ItemType: Equatable, Hashable {
    case user(User)
    case activityIndicator
    
    internal var id: String {
        switch self {
        case let .user(user): return "user_\(user.id)"
        case .activityIndicator: return "activityIndicator"
        }
    }
}

internal class SearchViewModel {
    internal enum SortType: String {
        case ascending
        case descending
        case none
    }
    
    internal enum LayoutType: Equatable {
        case loading
        case empty
        case content([ItemType])
        case error(String)
        
        internal var description: String {
            switch self {
            case .loading:
                return "LOADINGGGGG"
            case .empty:
                return "NO RESULTTTT"
            case let .error(message):
                return message
            case .content:
                return ""
            }
        }
    }
    
    @Published var sortType: SortType = .none
    @Published var query: String = ""
    @Published var layout: LayoutType = .empty
    @Published private(set) var errorMessage: String = ""
    @Published private(set) var isLoadMore: Bool = false
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
        guard
            case var .content(items) = layout,
            let index = items.firstIndex(where: { item in
                guard case let .user(userItem) = item else { return false }
                return userItem.id == user.id
            })
        else { return }
        
        let itemType = items[index]
        
        guard case var .user(item) = itemType else { return }
        
        let storageAction = item.isLiked ? globalStorage.removeFavorite(id: item.id, username: item.login) : globalStorage.saveFavorite(id: item.id, username: item.login)
        
        storageAction
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    guard let self else { return }
                    item.isLiked.toggle()
                    items[index] = .user(item)
                    layout = .content(items)
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
                isLoadMore = true
                layout = .loading
                return (query, pageNumber)
            }
        
        let loadMoreRequest = loadMoreSubject
            .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
            .map { [weak self] _ -> (String, Int) in
                guard let self else { return ("", 1) }
                pageNumber += 1
                isLoadMore = true
                return (query, pageNumber)
            }
        
        Publishers.Merge(
            queryRequest,
            loadMoreRequest
        )
        .removeDuplicates(by: { old, new in
            old.0 == new.0 && old.1 == new.1
        })
        .map { [weak self] query, page -> AnyPublisher<UserResponse, NetworkError> in
            guard let self, !query.isEmpty else {
                return Just(UserResponse())
                    .setFailureType(to: NetworkError.self)
                    .eraseToAnyPublisher()
            }
            
            return networkManager
                .getSearchResult(query: query, page: page)
                .eraseToAnyPublisher()
        }
        .switchToLatest()
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                guard let self else { return }
                
                switch completion {
                case .finished:
                    removeLoadingItem()
                case .failure(let error):
                    if layout == .empty {
                        layout = .error(error)
                    }
                    
                    pageNumber = 1
                }
            },
            receiveValue: { [weak self] userResponse in
                guard let self else { return }
                
                let users = userResponse.items
                
                if users.isEmpty {
                    layout = .empty
                    pageNumber = 1
                } else {
                    let totalUsers: [ItemType]
                    
                    if pageNumber > 1 {
                        let newUsers = generateUsersItem(from: users)
                        totalUsers = (users + newUsers)
                    } else {
                        totalUsers = generateUsersItem(from: users)
                    }
                    
                    let favoriteUsers = generateFavoriteUsers(for: totalUsers)
                    let finalUsers = sort(sortType, from: favoriteUsers)
                    
                    var items = finalUsers
                    
                    if userResponse.totalCount > finalUsers.count {
                        items.append(.activityIndicator)
                    }
                    
                    layout = .content(items)
                }
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
                guard let self, case let .content(users) = layout else { return }
                
                let sortedUsers = sort(type, from: users)
                layout = .content(sortedUsers)
            }).store(in: &cancellables)
    }
    
    private func generateFavoriteUsers(for items: [ItemType]) -> [ItemType] {
        items.compactMap { [weak self] item -> ItemType? in
            guard let self, case let .user(user) = item else { return item }
            var mutatedUser = user
            mutatedUser.isLiked = favoriteUsers.contains(where: { $0.id == user.id && $0.username == user.login })
            return mutatedUser
        }
    }
    
    private func generateUsersItem(from users: [User]) -> [ItemType] {
        users.map { user -> ItemType in
            .user(user)
        }
    }
    
    private func removeLoadingItem() {
        guard case let .content(items) = layout else { return }
        
        items.removeAll(where: { $0 == .activityIndicator })
    }
    
    private func reset() {
        layout = .empty
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
    
    private func sort(_ type: SortType, from items: [ItemType]) -> [ItemType] {
        switch sortType {
        case .ascending:
            return items.sorted { lItem, rItem in
                guard case let .user(lUser) = lItem, case let .user(rUser) = rItem else { return false }
                return lUser.login.lowercased() < rUser.login.lowercased()
            }
        case .descending:
            return items.sorted { lItem, rItem in
                guard case let .user(lUser) = lItem, case let .user(rUser) = rItem else { return false }
                return lUser.login.lowercased() > rUser.login.lowercased()
            }
        case .none:
            return items
        }
    }
}
