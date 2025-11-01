//
//  SearchViewController.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import UIKit

// TODO: FIX RADIO BUTTON UI
internal class SearchViewController: UIViewController {
    internal enum Section {
        case main
    }
    
    // MARK: - UI Components
    private let searchBar = UISearchBar()
    
    /// Sort Buttons
    private let ascendingButton = UIButton(type: .system)
    private let descendingButton = UIButton(type: .system)
    private let sortStackView = UIStackView()
    
    /// Container for table view or error view
    private let contentContainer: UIView = {
        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        return contentContainer
    }()
    
    private var currentContentView: UIView?
    
    private var tableView: UITableView?
    private var errorView: UIView?
    
    // MARK: - Properties
    private let viewModel = SearchViewModel()
    private var cancellables: Set<AnyCancellable> = []
    private var dataSource: UITableViewDiffableDataSource<Section, User>?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: TextNavigationItem())
        
        setupSearchBar()
        setupSortButtons()
        setupStackView()
        setupLayout()
        bindViewModel()
    }
    
    private func setupLayout() {
        view.addSubview(contentContainer)
        view.addSubview(sortStackView)
        view.addSubview(searchBar)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: navigationController?.navigationBar.frame.height ?? 0),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchBar.heightAnchor.constraint(equalToConstant: 56),
            
            sortStackView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            sortStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            contentContainer.topAnchor.constraint(equalTo: sortStackView.bottomAnchor, constant: 8),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupStackView() {
        sortStackView.addArrangedSubview(ascendingButton)
        sortStackView.addArrangedSubview(descendingButton)
        
        sortStackView.axis = .horizontal
        sortStackView.distribution = .fill
        sortStackView.alignment = .center
        sortStackView.spacing = 8
        sortStackView.translatesAutoresizingMaskIntoConstraints = false
        sortStackView.isHidden = true
    }
    
    private func setupSearchBar() {
        searchBar.delegate = self
        searchBar.placeholder = "Search"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupSortButtons() {
        ascendingButton.setTitle("ASC", for: .normal)
        descendingButton.setTitle("DESC", for: .normal)
        
        [ascendingButton, descendingButton].forEach { button in
            button.setImage(UIImage(systemName: "circle"), for: .normal)
            button.setImage(UIImage(systemName: "circle.fill"), for: .selected)
            button.setTitleColor(.label, for: .normal)
            button.backgroundColor = .clear
            
            button.addTarget(self, action: #selector(sortButtonTapped(_:)), for: .touchUpInside)
        }
    }
    
    @objc private func sortButtonTapped(_ sender: UIButton) {
        if sender == ascendingButton {
            ascendingButton.isSelected = true
            descendingButton.isSelected = false
        } else {
            ascendingButton.isSelected = false
            descendingButton.isSelected = true
        }
        
        if ascendingButton.isSelected {
            viewModel.sortType = .ascending
        } else if descendingButton.isSelected {
            viewModel.sortType = .descending
        } else {
            viewModel.sortType = .none
        }
    }
    
    private func showTableView() {
        removeCurrentContent()
        
        if tableView == nil {
            setupTableView()
        }
        
        guard let tableView = tableView else { return }
        
        addContentToContainer(tableView)
    }
    
    private func showErrorView(with message: String) {
        removeCurrentContent()
        
        let errorView = createErrorView(with: message)
        self.errorView = errorView
        
        addContentToContainer(errorView)
    }
    
    private func removeCurrentContent() {
        currentContentView?.removeFromSuperview()
        currentContentView = nil
    }
    
    private func addContentToContainer(_ contentView: UIView) {
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        currentContentView = contentView
    }
    
    private func setupTableView() {
        tableView = UITableView()
        guard let tableView = tableView else { return }
        
        dataSource = UITableViewDiffableDataSource<Section, User>(tableView: tableView) { [weak self] tableView, indexPath, user in
            guard let self = self else { return UITableViewCell() }
            
            let cell = tableView.dequeueReusableCell(withIdentifier: UserCell.identifier, for: indexPath) as? UserCell ?? UserCell()
            cell.configure(user: user)
            cell.delegate = self
            return cell
        }
        
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.register(UserCell.self, forCellReuseIdentifier: UserCell.identifier)
    }
    
    private func createErrorView(with message: String) -> UIView {
        let containerView = UIView()
        
        let errorLabel = UILabel()
        errorLabel.text = message
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont.preferredFont(forTextStyle: .body)
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(errorLabel)
        
        NSLayoutConstraint.activate([
            errorLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
        ])
        
        return containerView
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
                
                if !errorMessage.isEmpty {
                    showErrorView(with: errorMessage)
                    sortStackView.isHidden = true
                } else if !users.isEmpty {
                    showTableView()
                    updateSnapshot(with: users)
                    sortStackView.isHidden = false
                } else {
                    showErrorView(with: "No results found")
                    sortStackView.isHidden = true
                }
            }
            .store(in: &cancellables)
    }
}

extension SearchViewController: UITableViewDelegate {
    internal func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height
        
        if offsetY > contentHeight - frameHeight - 100 {
            viewModel.loadMoreSubject.send(())
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    internal func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        viewModel.query = searchText
    }
}

extension SearchViewController: UserCellDelegate {
    public func didTapLikeButton(for user: User) {
        viewModel.setFavorite(for: user)
    }
}
