//
//  SearchViewModelTests.swift
//  AstroGithubUser
//
//  Created by ByteDance on 02/11/25.
//

import Combine
import XCTest
@testable import AstroGithubUser

internal final class SearchViewModelTests: XCTestCase {
    
    private let mockNetworkManager = MockGithubNetworkManager()
    private let mockGlobalStorage = MockGlobalStorage()
    private var cancellables: Set<AnyCancellable> = []
    
    override func setUp() {
        super.setUp()
        cancellables = []
        mockNetworkManager.mockType = .normal
        mockGlobalStorage.mockType = .empty
    }
    
    override func tearDown() {
        cancellables = []
        mockNetworkManager.mockType = .normal
        mockGlobalStorage.mockType = .empty
        super.tearDown()
    }
    
    internal func testInitialState() throws {
        let viewModel = SearchViewModel(
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        XCTAssertEqual(viewModel.sortType, .none)
        XCTAssertEqual(viewModel.query, "")
        XCTAssertEqual(viewModel.layout, .empty)
        XCTAssertEqual(viewModel.errorMessage, "")
        XCTAssertEqual(viewModel.userPreference, nil)
        XCTAssertEqual(viewModel.favoriteUsers, [])
        XCTAssertEqual(viewModel.pageNumber, 1)
    }
    
    internal func testSearch() throws {
        mockNetworkManager.mockType = .normal
        
        let viewModel = SearchViewModel(
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Search completes")
        let mockUsers = MockUserResponse.normal.items
        let contentExpectation = generateSortedContents(mockUsers) + [.activityIndicator]
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if case .content(_) = layout {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.query = "query"
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fetchedLayout.count, 3) // empty, loading, and content
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    internal func testSearchWithAscendingSort() throws {
        mockNetworkManager.mockType = .normal
        
        let viewModel = SearchViewModel(
            sortType: .ascending,
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Search completes")
        let mockUsers = MockUserResponse.normal.items
        let contentExpectation = generateSortedContents(mockUsers, sortType: .ascending) + [.activityIndicator]
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if case .content(_) = layout {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.query = "query"
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fetchedLayout.count, 3) // empty, loading, and content
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    internal func testSearchWithDescendingSort() throws {
        mockNetworkManager.mockType = .normal
        
        let viewModel = SearchViewModel(
            sortType: .descending,
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Search completes")
        let mockUsers = MockUserResponse.normal.items
        let contentExpectation = generateSortedContents(mockUsers, sortType: .descending) + [.activityIndicator]
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if case .content(_) = layout {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.query = "query"
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fetchedLayout.count, 3) // empty, loading, and content
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    internal func testSearchWithFavoriteUser() throws {
        mockNetworkManager.mockType = .normal
        mockGlobalStorage.mockType = .normal
        
        let viewModel = SearchViewModel(
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Search completes")
        let mockUsers = MockUserResponse.normal.items.map { user in
            if user.id == 1 {
                var mutatedUser = user
                mutatedUser.isLiked = true
                return mutatedUser
            } else {
                return user
            }
        }
        let contentExpectation = generateSortedContents(mockUsers) + [.activityIndicator]
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if fetchedLayout.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.query = "query"
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fetchedLayout.count, 3) // empty, loading, and content
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    internal func testEmptyQuerySearch() throws {
        mockNetworkManager.mockType = .normal
        
        let viewModel = SearchViewModel(
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Search completes")
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if layout == .empty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.query = ""
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fetchedLayout.count, 1) // empty
        XCTAssertEqual(fetchedLayout.last, .empty)
    }
    
    internal func testFailSearch() throws {
        mockNetworkManager.mockType = .error
        
        let viewModel = SearchViewModel(
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Search fails")
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if case .error(_) = layout {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.query = "query"
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fetchedLayout.count, 3) // empty, loading, and error
        XCTAssertEqual(fetchedLayout.last, .error("Fail to fetch data"))
    }
    
    internal func testLoadMore() throws {
        mockNetworkManager.mockType = .normal
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        let initialUser = User(id: 0, login: "nol", avatarURL: "avatar-nol")
        let initialContent: [ItemType] = [.user(initialUser)]
        
        let viewModel = SearchViewModel(
            query: "query",
            layout: .content(initialContent + [.activityIndicator]),
            hasNext: true,
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Load more completes")
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if fetchedLayout.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let mockUsers = [initialUser] + MockUserResponse.normal.items
        let contentExpectation = generateSortedContents(mockUsers) + [.activityIndicator]
        
        viewModel.loadMoreSubject.send(())
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertEqual(viewModel.pageNumber, 2)
        XCTAssertEqual(fetchedLayout.count, 3) // content
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    internal func testLoadMoreFail() throws {
        print("testLoadMoreFail")
        mockNetworkManager.mockType = .error
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        let initialUser = User(id: 0, login: "nol", avatarURL: "avatar-nol")
        let initialContent: [ItemType] = [.user(initialUser), .activityIndicator]
        
        let viewModel = SearchViewModel(
            query: "query",
            layout: .content(initialContent),
            hasNext: true,
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Load more fail")
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if fetchedLayout.count == 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.loadMoreSubject.send(())
        
        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertEqual(viewModel.pageNumber, 1)
        XCTAssertEqual(fetchedLayout.count, 1) // content
        XCTAssertEqual(fetchedLayout.last, .content(initialContent))
    }
    
    internal func testSortAscending() throws {
        mockGlobalStorage.mockType = .normal
        mockGlobalStorage.sortType = .ascending
        
        let initialUsers = MockUserResponse.normal.items
        let initialContent = generateSortedContents(initialUsers) + [.activityIndicator]
        
        let viewModel = SearchViewModel(
            query: "query",
            layout: .content(initialContent),
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Ascending sort completes")
        let contentExpectation = generateSortedContents(initialUsers, sortType: .ascending) + [.activityIndicator]
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                print(layout)
                
                if fetchedLayout.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.updateSortSubject.send(.ascending)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.sortType, .ascending)
        XCTAssertEqual(fetchedLayout.count, 2)
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    internal func testSortDescending() throws {
        mockGlobalStorage.mockType = .normal
        mockGlobalStorage.sortType = .descending
        
        let initialUsers = MockUserResponse.normal.items
        let initialContent = generateSortedContents(initialUsers) + [.activityIndicator]
        
        let viewModel = SearchViewModel(
            query: "query",
            layout: .content(initialContent),
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Ascending sort completes")
        let contentExpectation = generateSortedContents(initialUsers, sortType: .descending) + [.activityIndicator]
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if fetchedLayout.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.updateSortSubject.send(.descending)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.sortType, .descending)
        XCTAssertEqual(fetchedLayout.count, 2)
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    internal func testSetFavorite() throws {
        mockNetworkManager.mockType = .normal
        mockGlobalStorage.mockType = .normal
        
        let initialUser = MockUserResponse.normal.items
        let initialContent = generateSortedContents(initialUser) + [.activityIndicator]
        let viewModel = SearchViewModel(
            query: "query",
            layout: .content(initialContent),
            networkManager: mockNetworkManager,
            debounce: 0,
            globalStorage: mockGlobalStorage
        )
        
        let expectation = XCTestExpectation(description: "Set favorite completes")
        
        let mockUsers = initialUser.map { user in
            if user.id == 1 {
                var mutatedUser = user
                mutatedUser.isLiked = true
                return mutatedUser
            } else {
                return user
            }
        }
        
        let contentExpectation = generateSortedContents(mockUsers) + [.activityIndicator]
        
        var fetchedLayout = [SearchViewModel.LayoutType]()
        
        viewModel.$layout
            .sink { layout in
                fetchedLayout.append(layout)
                
                if fetchedLayout.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        viewModel.setFavorite(for: mockUsers.first!)
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(fetchedLayout.last, .content(contentExpectation))
    }
    
    private func generateSortedContents(_ users: [User], sortType: SearchViewModel.SortType = .none) -> [ItemType] {
        let sortedUsers: [User]
        
        switch sortType {
        case .ascending:
            sortedUsers = users.sorted { $0.login < $1.login }
            
        case .descending:
            sortedUsers = users.sorted { $0.login > $1.login }
            
        case .none:
            sortedUsers = users
        }
        
        return sortedUsers.map { user -> ItemType in
                .user(user)
        }
    }
}
