//
//  UserCell.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Combine
import UIKit

internal class UserCell: UITableViewCell {
    internal static let identifier = "UserCell"
    
    internal weak var delegate: UserCellDelegate?
    
    private let profileImageView: UIImageView = {
        let profileImageView = UIImageView()
        profileImageView.layer.cornerRadius = 8
        profileImageView.clipsToBounds = true
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        return profileImageView
    }()
    
    private let nameLabel: UILabel = {
        let nameLabel = UILabel()
        nameLabel.font = UIFont.preferredFont(forTextStyle: .body)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        return nameLabel
    }()
    
    private let favoriteButton: UIButton = {
        let favoriteButton = UIButton()
        favoriteButton.setImage(UIImage(systemName: "heart"), for: .normal)
        favoriteButton.setImage(UIImage(systemName: "heart.fill"), for: .selected)
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        
        return favoriteButton
    }()
    
    private let stackView: UIStackView = UIStackView()
    private var cancellables: Set<AnyCancellable> = []
    
    private var viewModel: UserViewModel?
    
    internal override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupStackView()
        setupFavoriteButton()
        setupUI()
    }
    
    internal required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal override func prepareForReuse() {
        super.prepareForReuse()
        
        reset()
    }
    
    internal func configure(user: User) {
        reset()
        viewModel = UserViewModel(user: user)
        bindViewModel()
    }
    
    private func reset() {
        profileImageView.image = nil
        nameLabel.text = nil
        favoriteButton.isSelected = false
        delegate = nil
        cancellables = []
        viewModel?.cancelImageLoading()
    }
    
    private func setupUI() {
        contentView.addSubview(stackView)
        contentView.addSubview(favoriteButton)
        
        NSLayoutConstraint.activate([
            profileImageView.widthAnchor.constraint(equalToConstant: 40),
            profileImageView.heightAnchor.constraint(equalToConstant: 40),
            
            favoriteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: favoriteButton.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupStackView() {
        stackView.addArrangedSubview(profileImageView)
        stackView.addArrangedSubview(nameLabel)
        
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupFavoriteButton() {
        favoriteButton.addTarget(self, action: #selector(favoriteButtonTapped), for: .touchUpInside)
    }
    
    @objc private func favoriteButtonTapped() {
        if let viewModel = viewModel {
            delegate?.didTapLikeButton(for: viewModel.user)
        }
    }
    
    private func bindViewModel() {
        viewModel?.$name
            .receive(on: DispatchQueue.main)
            .sink { [weak self] name in
                guard let self else { return }
                nameLabel.text = name
            }.store(in: &cancellables)
        
        viewModel?.$profileImageData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] imageData in
                guard let self, let data = imageData else { return }
                profileImageView.image = UIImage(data: data)
            }.store(in: &cancellables)
        
        viewModel?.$isLiked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLiked in
                guard let self else { return }
                
                favoriteButton.isSelected = isLiked
                    
                let imageName = isLiked ? "heart.fill" : "heart"
                favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
            }.store(in: &cancellables)
    }
}
