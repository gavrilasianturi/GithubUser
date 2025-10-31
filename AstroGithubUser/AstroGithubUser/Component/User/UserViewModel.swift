//
//  UserViewModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

import Foundation

internal final class UserViewModel {
    @Published private(set) var profileImageData: Data?
    @Published private(set) var name: String = ""
    @Published private(set) var isLiked: Bool = false
    
    internal let user: User
    
    internal init(user: User) {
        self.user = user
        setupUI(user: user)
    }
    
    internal func setupUI(user: User) {
        name = user.login
        isLiked = user.isLiked
        
        Task {
            profileImageData = await loadImage(url: user.avatarURL)
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
}
