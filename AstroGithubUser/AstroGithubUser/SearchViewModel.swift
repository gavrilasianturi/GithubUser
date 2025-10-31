//
//  SearchViewModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import Foundation

internal class SearchViewModel {
    @Published internal var query = ""
    @Published private(set) var users: [User] = []
    @Published private(set) var errorMessage: String = ""
    
    private let networkManager: GithubNetworkManager
    private var cancellables: Set<AnyCancellable> = []
    
    internal init(networkManager: GithubNetworkManager = LiveGithubNetworkManager()) {
        self.networkManager = networkManager
        
        setupSearch()
    }
    
    private func setupSearch() {
        $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
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
                    .map { response -> [User] in
                        return response.items
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
}
