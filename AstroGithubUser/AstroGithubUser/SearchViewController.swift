//
//  SearchViewController.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import UIKit

internal class SearchViewController: UIViewController {
    internal enum Section {
        case main
    }
    
    // MARK: - UI Components
    private let searchBar = UISearchBar()
    
    private let tableView = UITableView()
    
    // MARK: - Properties
    private let viewModel = SearchViewModel()
    private var cancellables: Set<AnyCancellable> = []
    private var dataSource: UITableViewDiffableDataSource<Section, User>?
    
    internal override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: TextNavigationItem())
        
        setupSearchBar()
        setupTableView()
        setupLayout()
        bindViewModel()
    }
    
    private func setupLayout() {
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: navigationController?.navigationBar.frame.height ?? 0),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupTableView() {
        dataSource = UITableViewDiffableDataSource<Section, User>(tableView: tableView) { [weak self] tableView, indexPath, user in
            let cell = tableView.dequeueReusableCell(withIdentifier: UserCell.identifier, for: indexPath) as? UserCell ?? UserCell()
            cell.configure(user: user)
            return cell
        }
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = dataSource
        tableView.register(UserCell.self, forCellReuseIdentifier: UserCell.identifier)
    }
    
    private func updateSnapshot(with users: [User]) {
        guard let dataSource = dataSource else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, User>()
        snapshot.appendSections([.main])
        snapshot.appendItems(users)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func bindViewModel() {
        Publishers.CombineLatest(viewModel.$users, viewModel.$errorMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] users, errorMessage in
                guard let self else { return }
                updateSnapshot(with: users)
            }
            .store(in: &cancellables)
    }
}

extension SearchViewController: UISearchBarDelegate {
    internal func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.query = searchText
    }
}


