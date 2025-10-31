//
//  UserModel.swift
//  AstroGithubUser
//
//  Created by Gavrila on 31/10/25.
//

internal struct UserResponse: Decodable, Equatable {
    internal let items: [User]
}

internal struct User: Decodable, Equatable, Identifiable, Hashable, Sendable {
    internal let id: Int
    internal let login: String
    internal let avatarURL: String
    internal var isLiked: Bool = false
    
    internal enum CodingKeys: String, CodingKey {
        case id
        case login
        case avatarURL = "avatar_url"
    }
    
    internal init(
        id: Int,
        login: String,
        avatarURL: String
    ) {
        self.id = id
        self.login = login
        self.avatarURL = avatarURL
    }
    
    internal init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        self.login = try container.decodeIfPresent(String.self, forKey: .login) ?? ""
        self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL) ?? ""
    }
}
