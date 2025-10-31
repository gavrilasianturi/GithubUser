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
    
    private static let sortPreferenceKey = "SortPreferenceKey"
    
    @Published internal var query = ""
    @Published internal var sortType: SortType
    @Published private(set) var users: [User] = []
    @Published private(set) var errorMessage: String = ""
    
    private let networkManager: GithubNetworkManager
    private let debounce: Int
    private var cancellables: Set<AnyCancellable> = []
    
    internal init(
        networkManager: GithubNetworkManager = LiveGithubNetworkManager(),
        sortType: SortType = .none,
        debounce: Int = 300
    ) {
        self.networkManager = networkManager
        self.sortType = sortType
        self.debounce = debounce
        
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
                receiveValue: { [weak self] items in
                    guard let self else { return }
                    
                    users = items
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
    
    internal func setFavorite(for user: User) {
        guard let index = users.firstIndex(where: { $0.id == user.id }) else { return }
        users[index].isLiked.toggle()
    }
}
