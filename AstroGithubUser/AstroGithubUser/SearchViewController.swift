//
//  SearchViewController.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import UIKit

internal class SearchViewController: UIViewController {
    
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
    private var dataSource: UITableViewDiffableDataSource<Section, ItemType>?
    
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
            button.setImage(UIImage(systemName: "circle")?.withTintColor(.label, renderingMode: .alwaysOriginal), for: .normal)
            button.setImage(UIImage(systemName: "circle.fill")?.withTintColor(.label, renderingMode: .alwaysOriginal), for: .selected)
            button.setTitleColor(.label, for: .normal)
            button.setTitleColor(.label, for: .selected)
            button.backgroundColor = .clear
            button.tintColor = .clear
            button.translatesAutoresizingMaskIntoConstraints = false
            
            button.addTarget(self, action: #selector(sortButtonTapped(_:)), for: .touchUpInside)
        }
        
        bindSortButton(viewModel.sortType)
    }
    
    @objc private func sortButtonTapped(_ sender: UIButton) {
        if sender == ascendingButton {
            viewModel.updateSortSubject.send(.ascending)
        } else {
            viewModel.updateSortSubject.send(.descending)
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
    
    private func showTextView(with message: String) {
        removeCurrentContent()
        
        let errorView = createTextView(with: message)
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
        
        dataSource = UITableViewDiffableDataSource<Section, ItemType>(tableView: tableView) { [weak self] tableView, indexPath, item in
            guard let self = self else { return UITableViewCell() }
            
            switch item {
            case .user(let user):
                let cell = tableView.dequeueReusableCell(withIdentifier: UserCell.identifier, for: indexPath) as? UserCell ?? UserCell()
                cell.configure(user: user)
                cell.delegate = self
                return cell
                            
            case .activityIndicator:
                let cell = tableView.dequeueReusableCell(withIdentifier: LoadingCellView.identifier, for: indexPath) as? LoadingCellView ?? LoadingCellView()
                return cell
            }
        }
        
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.register(UserCell.self, forCellReuseIdentifier: UserCell.identifier)
        tableView.register(LoadingCellView.self, forCellReuseIdentifier: LoadingCellView.identifier)
    }
    
    private func createTextView(with message: String) -> UIView {
        let containerView = UIView()
        
        let infoLabel = UILabel()
        infoLabel.text = message
        infoLabel.textAlignment = .center
        infoLabel.font = UIFont.preferredFont(forTextStyle: .body)
        infoLabel.textColor = .systemRed
        infoLabel.numberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            infoLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            infoLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            infoLabel.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -20)
        ])
        
        return containerView
    }
    
    private func updateSnapshot(with items: [ItemType]) {
        guard let dataSource = dataSource else { return }
        
        var snapshot = NSDiffableDataSourceSnapshot<Section, ItemType>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items)
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func bindSortButton(_ type: SearchViewModel.SortType) {
        switch type {
        case .ascending:
            ascendingButton.isSelected = true
            descendingButton.isSelected = false
            
        case .descending:
            descendingButton.isSelected = true
            ascendingButton.isSelected = false
            
        case .none:
            ascendingButton.isSelected = false
            descendingButton.isSelected = false
        }
    }
    
    private func bindViewModel() {
        viewModel.$layout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] type in
                guard let self else { return }
                
                switch type {
                case let .content(items):
                    showTableView()
                    updateSnapshot(with: items)
                    sortStackView.isHidden = false
                    
                case .empty, .error, .loading:
                    showTextView(with: type.description)
                    sortStackView.isHidden = true
                }
            }
            .store(in: &cancellables)
        
        viewModel.$sortType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sortType in
                guard let self else { return }
                bindSortButton(sortType)
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
