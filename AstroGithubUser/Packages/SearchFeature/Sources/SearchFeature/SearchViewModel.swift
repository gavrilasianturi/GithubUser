//
//  SearchViewModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import Foundation
import SharedServices

public enum Section: Sendable {
    case main
}

public enum ItemType: Equatable, Hashable, Sendable {
    case user(User)
    case activityIndicator
    
    public var id: String {
        switch self {
        case let .user(user): return "user_\(user.id)"
        case .activityIndicator: return "activityIndicator"
        }
    }
}

public class SearchViewModel {
    public enum SortType: String {
        case ascending
        case descending
        case none
    }
    
    public enum LayoutType: Equatable {
        case loading
        case empty
        case content([ItemType])
        case error(String)
        
        public var description: String {
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
        
        public var allowErrorState: Bool {
            switch self {
            case .loading, .empty, .error(_):
                return true
            case .content:
                return false
            }
        }
    }
    
    @Published public var sortType: SortType
    @Published public var query: String
    @Published public var layout: LayoutType
    @Published public private(set) var userPreference: UserPreferenceData?
    
    public let loadMoreSubject = PassthroughSubject<Void, Never>()
    public let updateSortSubject = PassthroughSubject<SortType, Never>()
    
    public private(set) var favoriteUsers = Set<FavoriteUserData>()
    
    public var pageNumber: Int = 1
    public var hasNext: Bool = false
    
    private var cancellables: Set<AnyCancellable> = []
    
    private let networkManager: GithubNetworkManager
    private let globalStorage: GlobalStorage
    private let debounce: Int
    
    public init(
        sortType: SortType = .none,
        query: String = "",
        layout: LayoutType = .empty,
        userPreference: UserPreferenceData? = nil,
        pageNumber: Int = 1,
        hasNext: Bool = false,
        networkManager: GithubNetworkManager = LiveGithubNetworkManager(),
        debounce: Int = 300,
        globalStorage: GlobalStorage = CoreDataGlobalStorage()
    ) {
        self.sortType = sortType
        self.query = query
        self.layout = layout
        self.userPreference = userPreference
        self.networkManager = networkManager
        self.debounce = debounce
        self.globalStorage = globalStorage
        self.pageNumber = pageNumber
        self.hasNext = hasNext
        
        loadFavoriteStates()
        loadUserPreferenceState()
        setupSearch()
        setupSortedItems()
    }
    
    public func setFavorite(for user: User) {
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
            .dropFirst()
            .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
            .map { [weak self] query -> (String, Int) in
                guard let self else { return ("", 1) }
                reset()
                layout = .loading
                return (query, pageNumber)
            }
        
        let loadMoreRequest = loadMoreSubject
            .debounce(for: .milliseconds(debounce), scheduler: RunLoop.main)
            .filter { [weak self] _ in
                guard let self else { return false }
                return hasNext
            }
            .map { [weak self] _ -> (String, Int) in
                guard let self else { return ("", 1) }
                pageNumber += 1
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
                removeLoadingItem()
                
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    if layout.allowErrorState {
                        layout = .error(error.localizedDescription)
                        reset()
                    }
                }
            },
            receiveValue: { [weak self] userResponse in
                guard let self else { return }
                
                let users = userResponse.items
                let totalUsers: [ItemType]
                
                if pageNumber > 1 {
                    let currentUsers = generateCurrentUser()
                    let newUsers = generateUsersItem(from: users)
                    totalUsers = (currentUsers + newUsers)
                } else {
                    totalUsers = generateUsersItem(from: users)
                }
                
                if totalUsers.isEmpty {
                    layout = .empty
                    reset()
                } else {
                    let favoriteUsers = generateFavoriteUsers(for: totalUsers)
                    let finalUsers = sort(sortType, from: favoriteUsers)
                    
                    var items = finalUsers
                    
                    hasNext = userResponse.totalCount > finalUsers.count
                    
                    if hasNext {
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
            return .user(mutatedUser)
        }
    }
    
    private func generateUsersItem(from users: [User]) -> [ItemType] {
        users.map { user -> ItemType in
            .user(user)
        }
    }
    
    private func generateCurrentUser() -> [ItemType] {
        guard case let .content(items) = layout else { return [] }
        
        return items.compactMap { item -> ItemType? in
            guard case let .user(user) = item else { return nil }
            return .user(user)
        }
    }
    
    private func removeLoadingItem() {
        guard case var .content(items) = layout else { return }
        
        items.removeAll(where: { $0 == .activityIndicator })
        layout = .content(items)
    }
    
    private func reset() {
        pageNumber = 1
        hasNext = false
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
