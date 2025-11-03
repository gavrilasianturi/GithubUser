//
//  UserViewModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Foundation

@MainActor
internal protocol UserCellDelegate: AnyObject {
    func didTapLikeButton(for user: User)
}

internal final class UserViewModel: @unchecked Sendable {
    @Published private(set) var profileImageData: Data?
    @Published private(set) var name: String = ""
    @Published private(set) var isLiked: Bool = false
    
    internal let user: User
    
    private var imageLoadingTask: Task<Void, Never>?
    
    internal init(user: User) {
        self.user = user
        setupUI(user: user)
    }
    
    internal func setupUI(user: User) {
        name = user.login
        isLiked = user.isLiked
        
        cancelImageLoading()
        
        imageLoadingTask = Task { @Sendable [weak self] in
            guard !Task.isCancelled else { return }
            let imageData = await self?.loadImage(url: user.avatarURL)
            await MainActor.run {
                self?.profileImageData = imageData
            }
        }
    }
    
    internal func loadImage(url: String) async -> Data? {
        guard let url = URL(string: url) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }
    
    internal func cancelImageLoading() {
        imageLoadingTask?.cancel()
        imageLoadingTask = nil
    }
}
